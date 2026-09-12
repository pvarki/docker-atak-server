"""Merge deployment-owned settings into TAK's administrator-managed configuration."""

import argparse
import os
import tempfile
from copy import deepcopy
from pathlib import Path
from typing import cast

from lxml import etree

NS = "http://bbn.com/marti/xml/config"
NAMESPACES = {"c": NS}
# Only these attributes belong to deployment configuration. Everything else is
# retained from TAK's saved XML, including peers, groups, policy and extra ports.
MANAGED = {
    "network/input[@_name='stdssl']": (
        "_name",
        "protocol",
        "port",
        "coreVersion",
        "archive",
    ),
    "network/input[@_name='stdssl-noarchive']": (
        "_name",
        "protocol",
        "port",
        "coreVersion",
        "archive",
    ),
    "network/connector[@_name='https']": (
        "_name",
        "port",
        "enableWebtak",
        "enableNonAdminUI",
        "keystore",
        "keystoreFile",
        "keystorePass",
    ),
    "repository/connection": ("url", "username", "password"),
    "security/tls": (
        "context",
        "keymanager",
        "keystore",
        "keystoreFile",
        "keystorePass",
        "truststore",
        "truststoreFile",
        "truststorePass",
        "enableOCSP",
    ),
    "auth": ("default", "x509groups", "x509addAnonymous"),
    "auth/File": ("location",),
    "federation/federation-server": ("webBaseUrl",),
    "federation/federation-server/tls": (
        "keystore",
        "keystoreFile",
        "keystorePass",
        "keymanager",
    ),
}


def select(root: etree._Element, path: str) -> list[etree._Element]:
    """Select elements in TAK's namespace, including named listeners."""
    return cast(
        list[etree._Element],
        root.xpath(
            "/".join("c:" + part for part in path.split("/")), namespaces=NAMESPACES
        ),
    )


def one(root: etree._Element, path: str) -> etree._Element | None:
    """Ambiguous deployment-owned elements must be resolved by an administrator."""
    matches = select(root, path)
    if len(matches) > 1:
        raise ValueError(f"Multiple configuration elements match {path}")
    return matches[0] if matches else None


def require(root: etree._Element, path: str) -> etree._Element:
    """Return a required element with an explicit error if the saved XML lacks it."""
    element = one(root, path)
    if element is None:
        raise ValueError(f"Required configuration element missing: {path}")
    return element


def ensure(root: etree._Element, template: etree._Element, path: str) -> etree._Element:
    """Insert missing elements in template order without replacing existing siblings."""
    existing = one(root, path)
    if existing is not None:
        return existing
    source = one(template, path)
    if source is None:
        raise ValueError(f"Managed element missing from template: {path}")
    parent_path = path.rpartition("/")[0]
    parent = ensure(root, template, parent_path) if parent_path else root
    element = deepcopy(source)
    following_tags = [
        item.tag for item in source.itersiblings() if isinstance(item.tag, str)
    ]
    for index, sibling in enumerate(parent):
        if sibling.tag in following_tags and sibling.tag != element.tag:
            parent.insert(index, element)
            break
    else:
        parent.append(element)
    return element


def merge(saved: etree._Element, template: etree._Element) -> etree._Element:
    """Preserve admin settings and apply an explicit deployment ownership map."""
    result = deepcopy(saved)
    for path, attributes in MANAGED.items():
        source = one(template, path)
        if source is None:
            raise ValueError(f"Managed element missing from template: {path}")
        target = ensure(result, template, path)
        for attribute in attributes:
            if attribute in source.attrib:
                target.set(attribute, source.attrib[attribute])
            else:
                target.attrib.pop(attribute, None)

    # LDAP is configured entirely by the deployment environment. Other auth
    # providers and administrator additions outside this element are preserved.
    auth = require(result, "auth")
    for ldap in select(result, "auth/ldap"):
        auth.remove(ldap)
    if one(template, "auth/ldap") is not None:
        ensure(result, template, "auth/ldap")

    # Do not silently take an administrator's port for a new template listener.
    ports = set()
    for node in (
        select(result, "network/input")
        + select(result, "network/datafeed")
        + select(result, "network/connector")
    ):
        port = node.get("port")
        protocol = node.get("protocol", "tls")
        transport = "udp" if protocol in ("udp", "mcast", "quic") else "tcp"
        endpoint = (transport, node.get("iface", ""), port)
        if port and endpoint in ports:
            raise ValueError(f"Duplicate {transport} listener on port {port}")
        ports.add(endpoint)
    return result


def read_xml(path: Path) -> etree._Element:
    """Parse configuration without resolving external entities or DTDs."""
    parser = etree.XMLParser(
        resolve_entities=False, no_network=True, remove_blank_text=True
    )
    tree = etree.parse(str(path), parser)
    if tree.docinfo.doctype:
        raise ValueError(f"DOCTYPE is not allowed in {path}")
    if tree.getroot().tag != f"{{{NS}}}Configuration":
        raise ValueError(f"Not a TAK configuration: {path}")
    return tree.getroot()


def atomic_write(path: Path, data: bytes) -> None:
    """Publish complete configuration files with restrictive permissions."""
    descriptor, filename = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(filename, path)
    finally:
        Path(filename).unlink(missing_ok=True)


def prepare(
    template_path: Path,
    destination: Path,
    schema_path: Path,
    legacy_path: Path | None = None,
) -> None:
    """Validate before saving; prefer the config service's existing authoritative file."""
    schema = etree.XMLSchema(etree.parse(str(schema_path)))
    template = read_xml(template_path)
    schema.assertValid(template)
    source = destination if destination.exists() else legacy_path
    if source is not None and source.exists():
        saved = read_xml(source)
        result = merge(saved, template)
    else:
        result = template
    schema.assertValid(result)
    data = etree.tostring(
        result, xml_declaration=True, encoding="UTF-8", pretty_print=True
    )
    if destination.exists() and destination.read_bytes() == data:
        return
    if source is not None and source.exists():
        atomic_write(
            destination.with_suffix(".xml.pre-merge-backup"), source.read_bytes()
        )
    atomic_write(destination, data)


def main() -> None:
    """Prepare the configuration before the config service starts."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("template", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("schema", type=Path)
    parser.add_argument("--legacy", type=Path)
    args = parser.parse_args()
    prepare(args.template, args.destination, args.schema, args.legacy)


if __name__ == "__main__":
    main()
