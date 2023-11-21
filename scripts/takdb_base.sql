--
-- PostgreSQL database dump
--

-- Dumped from database version 12.16 (Debian 12.16-1.pgdg110+1)
-- Dumped by pg_dump version 12.16 (Debian 12.16-1.pgdg110+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: bitwiseandgroups(character varying, bit varying); Type: FUNCTION; Schema: public; Owner: tak
--

CREATE FUNCTION public.bitwiseandgroups(groupvector character varying, groups bit varying) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
BEGIN
	return groupVector::bit(32768) &
		lpad(groups::character varying, 32768, '0')::bit(32768)::bit varying <>
			0::bit(32768)::bit varying;
END;$$;


ALTER FUNCTION public.bitwiseandgroups(groupvector character varying, groups bit varying) OWNER TO tak;

--
-- Name: insert_data_feed_filter_groups(bigint, character varying[]); Type: FUNCTION; Schema: public; Owner: tak
--

CREATE FUNCTION public.insert_data_feed_filter_groups(data_feed_id bigint, VARIADIC data_feed_filter_groups character varying[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
    filter_group varchar;
begin
    FOREACH filter_group in array data_feed_filter_groups LOOP
        INSERT INTO data_feed_filter_group (data_feed_id, filter_group) VALUES( data_feed_id, filter_group) ON CONFLICT DO NOTHING;
    end LOOP;
END;
$$;


ALTER FUNCTION public.insert_data_feed_filter_groups(data_feed_id bigint, VARIADIC data_feed_filter_groups character varying[]) OWNER TO tak;

--
-- Name: insert_data_feed_tags(bigint, character varying[]); Type: FUNCTION; Schema: public; Owner: tak
--

CREATE FUNCTION public.insert_data_feed_tags(data_feed_id bigint, VARIADIC data_feed_tags character varying[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
    tag varchar;
begin
    FOREACH tag in array data_feed_tags LOOP
        INSERT INTO data_feed_tag (data_feed_id, tag) VALUES( data_feed_id, tag) ON CONFLICT DO NOTHING;
    end LOOP;
END;
$$;


ALTER FUNCTION public.insert_data_feed_tags(data_feed_id bigint, VARIADIC data_feed_tags character varying[]) OWNER TO tak;

--
-- Name: sha256(bytea); Type: FUNCTION; Schema: public; Owner: tak
--

CREATE FUNCTION public.sha256(bytea) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
   SELECT encode(digest($1, 'sha256'), 'hex')
 $_$;


ALTER FUNCTION public.sha256(bytea) OWNER TO tak;

--
-- Name: ts_hour_trigger(); Type: FUNCTION; Schema: public; Owner: tak
--

CREATE FUNCTION public.ts_hour_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                declare ts timestamp (3) with time zone := now();
                begin
                new.servertime := ts;
                new.servertime_hour := date_trunc('hour', ts);
                return new;
                end;
 $$;


ALTER FUNCTION public.ts_hour_trigger() OWNER TO tak;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_group_cache; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.active_group_cache (
    id integer NOT NULL,
    username character varying,
    groupname character varying,
    direction character varying,
    enabled boolean DEFAULT false
);


ALTER TABLE public.active_group_cache OWNER TO tak;

--
-- Name: active_group_cache_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.active_group_cache_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.active_group_cache_id_seq OWNER TO tak;

--
-- Name: active_group_cache_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.active_group_cache_id_seq OWNED BY public.active_group_cache.id;


--
-- Name: caveat; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.caveat (
    id bigint NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.caveat OWNER TO tak;

--
-- Name: caveat_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.caveat_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.caveat_id_seq OWNER TO tak;

--
-- Name: caveat_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.caveat_id_seq OWNED BY public.caveat.id;


--
-- Name: certificate_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.certificate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.certificate_id_seq OWNER TO tak;

--
-- Name: certificate; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.certificate (
    id integer DEFAULT nextval('public.certificate_id_seq'::regclass) NOT NULL,
    creator_dn character varying(1000),
    subject_dn character varying(1000) NOT NULL,
    user_dn character varying(1000) NOT NULL,
    issuance_date timestamp(3) with time zone NOT NULL,
    effective_date timestamp(3) with time zone NOT NULL,
    expiration_date timestamp(3) with time zone NOT NULL,
    revocation_date timestamp(3) with time zone,
    certificate text NOT NULL,
    hash character varying(1000),
    client_uid character varying,
    token character varying
);


ALTER TABLE public.certificate OWNER TO tak;

--
-- Name: certificate_private_key; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.certificate_private_key (
    certificate_id integer NOT NULL,
    key_format_code character varying(255) NOT NULL,
    key text NOT NULL
);


ALTER TABLE public.certificate_private_key OWNER TO tak;

--
-- Name: ci_trap; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.ci_trap (
    id integer NOT NULL,
    type character varying,
    user_callsign character varying,
    user_description character varying,
    date_time timestamp with time zone,
    date_time_description character varying,
    location_description character varying,
    event_scale character varying,
    importance character varying,
    uid character varying,
    location public.geometry,
    hash character varying,
    xml character varying,
    groups bit varying,
    title character varying
);


ALTER TABLE public.ci_trap OWNER TO tak;

--
-- Name: ci_trap_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.ci_trap_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ci_trap_id_seq OWNER TO tak;

--
-- Name: ci_trap_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.ci_trap_id_seq OWNED BY public.ci_trap.id;


--
-- Name: classification; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.classification (
    id bigint NOT NULL,
    level text NOT NULL
);


ALTER TABLE public.classification OWNER TO tak;

--
-- Name: classification_caveat; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.classification_caveat (
    classification_id bigint NOT NULL,
    caveat_id integer NOT NULL
);


ALTER TABLE public.classification_caveat OWNER TO tak;

--
-- Name: classification_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.classification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.classification_id_seq OWNER TO tak;

--
-- Name: classification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.classification_id_seq OWNED BY public.classification.id;


--
-- Name: client_endpoint_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.client_endpoint_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.client_endpoint_id_seq OWNER TO tak;

--
-- Name: client_endpoint; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.client_endpoint (
    id integer DEFAULT nextval('public.client_endpoint_id_seq'::regclass) NOT NULL,
    callsign character varying(100) NOT NULL,
    uid character varying(100) NOT NULL,
    username text
);


ALTER TABLE public.client_endpoint OWNER TO tak;

--
-- Name: TABLE client_endpoint; Type: COMMENT; Schema: public; Owner: tak
--

COMMENT ON TABLE public.client_endpoint IS 'TAK server client endpoints.';


--
-- Name: client_endpoint_event_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.client_endpoint_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.client_endpoint_event_id_seq OWNER TO tak;

--
-- Name: client_endpoint_event; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.client_endpoint_event (
    id integer DEFAULT nextval('public.client_endpoint_event_id_seq'::regclass) NOT NULL,
    client_endpoint_id integer NOT NULL,
    connection_event_type_id integer NOT NULL,
    created_ts timestamp(3) with time zone NOT NULL,
    client_version character varying(255),
    groups bit varying
);


ALTER TABLE public.client_endpoint_event OWNER TO tak;

--
-- Name: clientdetails; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.clientdetails (
    appid character varying(256) NOT NULL,
    resourceids character varying(256),
    appsecret character varying(256),
    scope character varying(256),
    granttypes character varying(256),
    redirecturl character varying(256),
    authorities character varying(256),
    access_token_validity integer,
    refresh_token_validity integer,
    additionalinformation character varying(4096),
    autoapprovescopes character varying(256)
);


ALTER TABLE public.clientdetails OWNER TO tak;

--
-- Name: connection_event_type_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.connection_event_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.connection_event_type_id_seq OWNER TO tak;

--
-- Name: connection_event_type; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.connection_event_type (
    id integer DEFAULT nextval('public.connection_event_type_id_seq'::regclass) NOT NULL,
    event_name character varying(30) NOT NULL
);


ALTER TABLE public.connection_event_type OWNER TO tak;

--
-- Name: cot_image; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.cot_image (
    id integer NOT NULL,
    image bytea,
    cot_id integer NOT NULL
);


ALTER TABLE public.cot_image OWNER TO tak;

--
-- Name: cot_image_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.cot_image_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cot_image_id_seq OWNER TO tak;

--
-- Name: cot_image_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.cot_image_id_seq OWNED BY public.cot_image.id;


--
-- Name: cot_image_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.cot_image_seq
    START WITH 101
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cot_image_seq OWNER TO tak;

--
-- Name: cot_link; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.cot_link (
    id integer NOT NULL,
    containing_event integer NOT NULL,
    target_uid character varying NOT NULL,
    target_type character varying NOT NULL,
    relation character varying NOT NULL,
    url character varying,
    remarks character varying,
    mime_type character varying,
    version character varying DEFAULT '1.7'::character varying
);


ALTER TABLE public.cot_link OWNER TO tak;

--
-- Name: cot_link_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.cot_link_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cot_link_id_seq OWNER TO tak;

--
-- Name: cot_link_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.cot_link_id_seq OWNED BY public.cot_link.id;


--
-- Name: cot_router; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.cot_router (
    id integer NOT NULL,
    uid character varying NOT NULL,
    cot_type character varying,
    access character varying,
    qos character varying,
    opex character varying,
    start timestamp(3) with time zone,
    "time" timestamp(3) with time zone,
    stale timestamp(3) with time zone,
    how character varying,
    point_hae numeric,
    point_ce numeric,
    point_le numeric,
    detail text,
    servertime timestamp(3) with time zone DEFAULT now(),
    servertime_hour timestamp(3) with time zone DEFAULT date_trunc('hour'::text, now()),
    event_pt public.geometry(Point,4326),
    groups bit varying,
    caveat text,
    releaseableto text
);


ALTER TABLE public.cot_router OWNER TO tak;

--
-- Name: cot_router_chat; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.cot_router_chat (
    id integer NOT NULL,
    uid character varying NOT NULL,
    cot_type character varying,
    access character varying,
    qos character varying,
    opex character varying,
    start timestamp(3) with time zone,
    "time" timestamp(3) with time zone,
    stale timestamp(3) with time zone,
    how character varying,
    point_hae numeric,
    point_ce numeric,
    point_le numeric,
    groups bit varying,
    detail text,
    servertime timestamp(3) with time zone,
    sender_callsign character varying,
    dest_callsign character varying,
    dest_uid character varying,
    chat_content character varying,
    chat_room character varying,
    event_pt public.geometry(Point,4326)
);


ALTER TABLE public.cot_router_chat OWNER TO tak;

--
-- Name: cot_router_chat_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.cot_router_chat_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cot_router_chat_id_seq OWNER TO tak;

--
-- Name: cot_router_chat_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.cot_router_chat_id_seq OWNED BY public.cot_router_chat.id;


--
-- Name: cot_router_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.cot_router_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cot_router_id_seq OWNER TO tak;

--
-- Name: cot_router_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.cot_router_id_seq OWNED BY public.cot_router.id;


--
-- Name: cot_router_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.cot_router_seq
    START WITH 101
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cot_router_seq OWNER TO tak;

--
-- Name: cot_thumbnail; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.cot_thumbnail (
    id integer NOT NULL,
    thumbnail bytea,
    cot_id integer NOT NULL,
    cot_image_id integer NOT NULL
);


ALTER TABLE public.cot_thumbnail OWNER TO tak;

--
-- Name: cot_thumbnail_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.cot_thumbnail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cot_thumbnail_id_seq OWNER TO tak;

--
-- Name: cot_thumbnail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.cot_thumbnail_id_seq OWNED BY public.cot_thumbnail.id;


--
-- Name: cot_thumbnail_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.cot_thumbnail_seq
    START WITH 101
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cot_thumbnail_seq OWNER TO tak;

--
-- Name: data_feed; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.data_feed (
    id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    type bigint NOT NULL,
    auth character varying(255),
    port bigint,
    auth_required boolean DEFAULT false,
    protocol character varying(255),
    feed_group character varying(255),
    iface character varying(255),
    archive boolean DEFAULT true,
    anongroup boolean DEFAULT false,
    sync boolean DEFAULT false,
    archive_only boolean DEFAULT false,
    core_version bigint,
    core_version_tls_versions character varying(255),
    groups bit varying,
    sync_cache_retention_seconds bigint DEFAULT 3600,
    federated boolean DEFAULT true,
    binary_payload_websocket_only boolean DEFAULT false,
    predicate_lang text,
    data_source_endpoint text,
    predicate text,
    auth_type text
);


ALTER TABLE public.data_feed OWNER TO tak;

--
-- Name: data_feed_cot; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.data_feed_cot (
    cot_router_id integer NOT NULL,
    data_feed_id integer NOT NULL
);


ALTER TABLE public.data_feed_cot OWNER TO tak;

--
-- Name: data_feed_filter_group; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.data_feed_filter_group (
    data_feed_id bigint NOT NULL,
    filter_group character varying(255) NOT NULL
);


ALTER TABLE public.data_feed_filter_group OWNER TO tak;

--
-- Name: data_feed_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.data_feed_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.data_feed_id_seq OWNER TO tak;

--
-- Name: data_feed_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.data_feed_id_seq OWNED BY public.data_feed.id;


--
-- Name: data_feed_tag; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.data_feed_tag (
    data_feed_id bigint NOT NULL,
    tag character varying(255) NOT NULL
);


ALTER TABLE public.data_feed_tag OWNER TO tak;

--
-- Name: data_feed_type_pl; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.data_feed_type_pl (
    id integer NOT NULL,
    feed_type text NOT NULL
);


ALTER TABLE public.data_feed_type_pl OWNER TO tak;

--
-- Name: data_feed_type_pl_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.data_feed_type_pl_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.data_feed_type_pl_id_seq OWNER TO tak;

--
-- Name: data_feed_type_pl_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.data_feed_type_pl_id_seq OWNED BY public.data_feed_type_pl.id;


--
-- Name: device_profile; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.device_profile (
    id bigint NOT NULL,
    name character varying(255),
    groups bit varying,
    apply_on_enrollment boolean DEFAULT true,
    apply_on_connect boolean DEFAULT false,
    active boolean DEFAULT true,
    updated timestamp(3) with time zone NOT NULL,
    tool character varying(255)
);


ALTER TABLE public.device_profile OWNER TO tak;

--
-- Name: device_profile_directory; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.device_profile_directory (
    id bigint NOT NULL,
    path character varying(255),
    device_profile_id bigint
);


ALTER TABLE public.device_profile_directory OWNER TO tak;

--
-- Name: device_profile_directory_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.device_profile_directory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.device_profile_directory_id_seq OWNER TO tak;

--
-- Name: device_profile_directory_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.device_profile_directory_id_seq OWNED BY public.device_profile_directory.id;


--
-- Name: device_profile_file; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.device_profile_file (
    id bigint NOT NULL,
    name character varying(255),
    data bytea,
    device_profile_id bigint
);


ALTER TABLE public.device_profile_file OWNER TO tak;

--
-- Name: device_profile_file_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.device_profile_file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.device_profile_file_id_seq OWNER TO tak;

--
-- Name: device_profile_file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.device_profile_file_id_seq OWNED BY public.device_profile_file.id;


--
-- Name: device_profile_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.device_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.device_profile_id_seq OWNER TO tak;

--
-- Name: device_profile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.device_profile_id_seq OWNED BY public.device_profile.id;


--
-- Name: error_logs; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.error_logs (
    id integer NOT NULL,
    uid text,
    callsign text,
    log text,
    "time" timestamp(3) with time zone DEFAULT now(),
    filename text,
    major_version text,
    minor_version text,
    platform text,
    contents bytea
);


ALTER TABLE public.error_logs OWNER TO tak;

--
-- Name: error_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.error_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.error_logs_id_seq OWNER TO tak;

--
-- Name: error_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.error_logs_id_seq OWNED BY public.error_logs.id;


--
-- Name: fed_event; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.fed_event (
    fed_id text NOT NULL,
    fed_name text NOT NULL,
    event_kind_id integer NOT NULL,
    event_time timestamp(3) with time zone NOT NULL,
    remote boolean NOT NULL,
    details jsonb
);


ALTER TABLE public.fed_event OWNER TO tak;

--
-- Name: fed_event_kind_pl; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.fed_event_kind_pl (
    id integer NOT NULL,
    event_kind text NOT NULL
);


ALTER TABLE public.fed_event_kind_pl OWNER TO tak;

--
-- Name: fed_event_kind_pl_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.fed_event_kind_pl_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fed_event_kind_pl_id_seq OWNER TO tak;

--
-- Name: fed_event_kind_pl_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.fed_event_kind_pl_id_seq OWNED BY public.fed_event_kind_pl.id;


--
-- Name: group_bitpos_sequence; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.group_bitpos_sequence (
    bitpos integer NOT NULL
);


ALTER TABLE public.group_bitpos_sequence OWNER TO tak;

--
-- Name: group_type_pl; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.group_type_pl (
    id integer NOT NULL,
    type text NOT NULL
);


ALTER TABLE public.group_type_pl OWNER TO tak;

--
-- Name: group_type_pl_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.group_type_pl_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.group_type_pl_id_seq OWNER TO tak;

--
-- Name: group_type_pl_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.group_type_pl_id_seq OWNED BY public.group_type_pl.id;


--
-- Name: groups; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.groups (
    id bigint NOT NULL,
    name text NOT NULL,
    bitpos integer NOT NULL,
    create_ts timestamp(3) with time zone NOT NULL,
    type integer NOT NULL
);


ALTER TABLE public.groups OWNER TO tak;

--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.groups_id_seq OWNER TO tak;

--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.groups_id_seq OWNED BY public.groups.id;


--
-- Name: icon; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.icon (
    id bigint NOT NULL,
    bytes bytea,
    group_name character varying(255),
    iconsetuid character varying(255),
    mimetype character varying(255),
    name character varying(255),
    type2525b character varying(255),
    iconset_id bigint,
    created timestamp with time zone
);


ALTER TABLE public.icon OWNER TO tak;

--
-- Name: icon_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.icon_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.icon_id_seq OWNER TO tak;

--
-- Name: icon_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.icon_id_seq OWNED BY public.icon.id;


--
-- Name: iconset; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.iconset (
    id bigint NOT NULL,
    defaultfriendly character varying(255),
    defaulthostile character varying(255),
    defaultunknown character varying(255),
    name character varying(255),
    skipresize boolean,
    uid character varying(255) NOT NULL,
    version integer,
    created timestamp with time zone
);


ALTER TABLE public.iconset OWNER TO tak;

--
-- Name: iconset_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.iconset_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.iconset_id_seq OWNER TO tak;

--
-- Name: iconset_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.iconset_id_seq OWNED BY public.iconset.id;


--
-- Name: latestcot; Type: VIEW; Schema: public; Owner: tak
--

CREATE VIEW public.latestcot AS
 SELECT cot.id,
    cot.uid,
    cot.cot_type,
    cot.access,
    cot.qos,
    cot.opex,
    cot.start,
    cot."time",
    cot.stale,
    cot.how,
    cot.point_hae,
    cot.point_ce,
    cot.point_le,
    cot.detail,
    cot.servertime,
    cot.event_pt
   FROM (public.cot_router cot
     JOIN ( SELECT cot_router.uid,
            max(cot_router.servertime) AS lastreceivetime
           FROM public.cot_router
          GROUP BY cot_router.uid) groupedcot ON ((((cot.uid)::text = (groupedcot.uid)::text) AND (cot.servertime = groupedcot.lastreceivetime))))
  ORDER BY cot.id;


ALTER TABLE public.latestcot OWNER TO tak;

--
-- Name: resource; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.resource (
    id integer NOT NULL,
    altitude numeric,
    data bytea,
    filename character varying(2048),
    keywords character varying(128)[],
    location public.geometry(Point,4326),
    mimetype character varying(256),
    name character varying(128),
    permissions character varying(128)[],
    remarks character varying(2048),
    submissiontime timestamp(3) with time zone DEFAULT now(),
    submitter character varying(128),
    uid character varying(128),
    hash text,
    creatoruid character varying(256),
    tool character varying,
    groups bit varying,
    expiration bigint DEFAULT '-1'::integer
);


ALTER TABLE public.resource OWNER TO tak;

--
-- Name: latestresource; Type: VIEW; Schema: public; Owner: tak
--

CREATE VIEW public.latestresource AS
 SELECT resource.id,
    resource.altitude,
    resource.data,
    resource.filename,
    resource.keywords,
    resource.location,
    resource.mimetype,
    resource.name,
    resource.permissions,
    resource.remarks,
    resource.submissiontime,
    resource.submitter,
    resource.uid,
    resource.hash,
    resource.groups,
    resource.tool
   FROM (public.resource
     JOIN ( SELECT resource_1.uid,
            max(resource_1.submissiontime) AS latestupload
           FROM public.resource resource_1
          GROUP BY resource_1.uid) groupedresource ON ((((resource.uid)::text = (groupedresource.uid)::text) AND (resource.submissiontime = groupedresource.latestupload))))
  ORDER BY resource.id;


ALTER TABLE public.latestresource OWNER TO tak;

--
-- Name: maplayer; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.maplayer (
    id bigint NOT NULL,
    create_time timestamp(3) with time zone NOT NULL,
    modified_time timestamp(3) with time zone NOT NULL,
    uid character varying(255) NOT NULL,
    creator_uid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255),
    type character varying(255) NOT NULL,
    url character varying(255) NOT NULL,
    default_layer boolean DEFAULT false,
    enabled boolean DEFAULT false,
    min_zoom integer,
    max_zoom integer,
    tile_type character varying(255),
    server_parts character varying(255),
    background_color character varying(255),
    tile_update character varying(255),
    ignore_errors boolean DEFAULT false,
    invert_y_coordinate boolean DEFAULT false,
    mission_id bigint,
    north numeric,
    south numeric,
    east numeric,
    west numeric,
    additional_parameters character varying(255),
    coordinate_system character varying(255),
    version character varying(255),
    opacity integer,
    layers character varying(255),
    path text,
    after text
);


ALTER TABLE public.maplayer OWNER TO tak;

--
-- Name: maplayer_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.maplayer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.maplayer_id_seq OWNER TO tak;

--
-- Name: maplayer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.maplayer_id_seq OWNED BY public.maplayer.id;


--
-- Name: mission; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    creatoruid character varying(255),
    create_change_id bigint,
    create_time timestamp(3) with time zone NOT NULL,
    tool character varying,
    groups bit varying,
    chatroom character varying(255),
    description character varying(255),
    parent_mission_id bigint,
    password_hash text,
    default_role_id bigint,
    expiration bigint DEFAULT '-1'::integer,
    base_layer text,
    bbox text,
    path text,
    classification text,
    last_edited timestamp(3) with time zone,
    bounding_polygon text,
    invite_only boolean DEFAULT false,
    guid uuid
);


ALTER TABLE public.mission OWNER TO tak;

--
-- Name: mission_change_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.mission_change_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mission_change_id_seq OWNER TO tak;

--
-- Name: mission_change; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_change (
    id bigint DEFAULT nextval('public.mission_change_id_seq'::regclass) NOT NULL,
    hash character varying(255),
    uid character varying(255),
    mission_name character varying(255),
    ts timestamp(3) with time zone NOT NULL,
    change_type integer NOT NULL,
    mission_id bigint,
    creatoruid character varying(255),
    external_data_token character varying(255),
    external_data_name character varying(255),
    external_data_tool character varying(255),
    external_data_uid character varying(255),
    external_data_notes character varying(255),
    servertime timestamp(3) with time zone,
    mission_feed_uid character varying(255),
    map_layer_uid character varying(255),
    remote_federated_change boolean DEFAULT false
);


ALTER TABLE public.mission_change OWNER TO tak;

--
-- Name: mission_external_data; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_external_data (
    id character varying(255),
    name text,
    tool text,
    url_data text,
    url_display text,
    mission_id bigint,
    notes character varying(255)
);


ALTER TABLE public.mission_external_data OWNER TO tak;

--
-- Name: mission_feed; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_feed (
    uid character varying(255),
    data_feed_uid text,
    filter_polygon text,
    filter_cot_types text,
    filter_callsign text,
    mission_id bigint
);


ALTER TABLE public.mission_feed OWNER TO tak;

--
-- Name: mission_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.mission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mission_id_seq OWNER TO tak;

--
-- Name: mission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.mission_id_seq OWNED BY public.mission.id;


--
-- Name: mission_invitation_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.mission_invitation_id_seq
    START WITH 7602
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mission_invitation_id_seq OWNER TO tak;

--
-- Name: mission_invitation; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_invitation (
    id bigint DEFAULT nextval('public.mission_invitation_id_seq'::regclass) NOT NULL,
    mission_name text NOT NULL,
    invitee text NOT NULL,
    type text NOT NULL,
    creator_uid text,
    create_time timestamp with time zone,
    token text,
    role_id bigint,
    mission_id bigint
);


ALTER TABLE public.mission_invitation OWNER TO tak;

--
-- Name: mission_keyword; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_keyword (
    mission_id bigint NOT NULL,
    keyword character varying(255) NOT NULL
);


ALTER TABLE public.mission_keyword OWNER TO tak;

--
-- Name: mission_layer; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_layer (
    uid character varying(255),
    name text,
    type integer,
    parent_node_uid character varying(255),
    mission_id bigint,
    after text
);


ALTER TABLE public.mission_layer OWNER TO tak;

--
-- Name: mission_log; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_log (
    id character varying(255) NOT NULL,
    content text NOT NULL,
    creator_uid text,
    dtg timestamp(3) with time zone,
    entry_uid text,
    servertime timestamp(3) with time zone,
    created timestamp(3) with time zone
);


ALTER TABLE public.mission_log OWNER TO tak;

--
-- Name: mission_log_hash; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_log_hash (
    mission_log_id character varying(255) NOT NULL,
    contenthashes text NOT NULL
);


ALTER TABLE public.mission_log_hash OWNER TO tak;

--
-- Name: mission_log_keyword; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_log_keyword (
    mission_log_id character varying(255) NOT NULL,
    keyword character varying(255) NOT NULL
);


ALTER TABLE public.mission_log_keyword OWNER TO tak;

--
-- Name: mission_log_mission_name; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_log_mission_name (
    mission_log_id character varying(255) NOT NULL,
    missionnames character varying(255) NOT NULL
);


ALTER TABLE public.mission_log_mission_name OWNER TO tak;

--
-- Name: mission_resource; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_resource (
    mission_id bigint NOT NULL,
    resource_id integer NOT NULL,
    resource_hash character varying(255) NOT NULL
);


ALTER TABLE public.mission_resource OWNER TO tak;

--
-- Name: mission_resource_keyword; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_resource_keyword (
    id bigint NOT NULL,
    mission_id bigint NOT NULL,
    hash character varying(255) NOT NULL,
    keyword character varying(255) NOT NULL
);


ALTER TABLE public.mission_resource_keyword OWNER TO tak;

--
-- Name: mission_resource_keyword_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.mission_resource_keyword_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mission_resource_keyword_id_seq OWNER TO tak;

--
-- Name: mission_resource_keyword_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.mission_resource_keyword_id_seq OWNED BY public.mission_resource_keyword.id;


--
-- Name: mission_subscription; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_subscription (
    mission_id bigint NOT NULL,
    client_uid text NOT NULL,
    create_time timestamp(3) with time zone NOT NULL,
    uid text,
    token text,
    role_id bigint,
    username text
);


ALTER TABLE public.mission_subscription OWNER TO tak;

--
-- Name: mission_uid; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_uid (
    mission_id bigint NOT NULL,
    uid character varying(255) NOT NULL
);


ALTER TABLE public.mission_uid OWNER TO tak;

--
-- Name: mission_uid_keyword; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.mission_uid_keyword (
    id bigint NOT NULL,
    mission_id bigint NOT NULL,
    uid character varying(255) NOT NULL,
    keyword character varying(255) NOT NULL
);


ALTER TABLE public.mission_uid_keyword OWNER TO tak;

--
-- Name: mission_uid_keyword_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.mission_uid_keyword_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mission_uid_keyword_id_seq OWNER TO tak;

--
-- Name: mission_uid_keyword_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.mission_uid_keyword_id_seq OWNED BY public.mission_uid_keyword.id;


--
-- Name: oauth_access_token; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.oauth_access_token (
    token_id character varying(256),
    token bytea,
    authentication_id character varying(256) NOT NULL,
    user_name character varying(256),
    client_id character varying(256),
    authentication bytea,
    refresh_token character varying(256)
);


ALTER TABLE public.oauth_access_token OWNER TO tak;

--
-- Name: oauth_approvals; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.oauth_approvals (
    userid character varying(256),
    clientid character varying(256),
    scope character varying(256),
    status character varying(10),
    expiresat timestamp without time zone,
    lastmodifiedat timestamp without time zone
);


ALTER TABLE public.oauth_approvals OWNER TO tak;

--
-- Name: oauth_client_details; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.oauth_client_details (
    client_id character varying(256) NOT NULL,
    resource_ids character varying(256),
    client_secret character varying(256),
    scope character varying(256),
    authorized_grant_types character varying(256),
    web_server_redirect_uri character varying(256),
    authorities character varying(256),
    access_token_validity integer,
    refresh_token_validity integer,
    additional_information character varying(4096),
    autoapprove character varying(256)
);


ALTER TABLE public.oauth_client_details OWNER TO tak;

--
-- Name: oauth_client_token; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.oauth_client_token (
    token_id character varying(256),
    token bytea,
    authentication_id character varying(256) NOT NULL,
    user_name character varying(256),
    client_id character varying(256)
);


ALTER TABLE public.oauth_client_token OWNER TO tak;

--
-- Name: oauth_code; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.oauth_code (
    code character varying(256),
    authentication bytea
);


ALTER TABLE public.oauth_code OWNER TO tak;

--
-- Name: oauth_refresh_token; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.oauth_refresh_token (
    token_id character varying(256),
    token bytea,
    authentication bytea
);


ALTER TABLE public.oauth_refresh_token OWNER TO tak;

--
-- Name: permission; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.permission (
    id bigint NOT NULL,
    permission integer NOT NULL
);


ALTER TABLE public.permission OWNER TO tak;

--
-- Name: permission_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.permission_id_seq OWNER TO tak;

--
-- Name: permission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.permission_id_seq OWNED BY public.permission.id;


--
-- Name: properties_keys; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.properties_keys (
    id bigint NOT NULL,
    properties_uid_id bigint NOT NULL,
    key text NOT NULL
);


ALTER TABLE public.properties_keys OWNER TO tak;

--
-- Name: properties_key_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.properties_key_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.properties_key_id_seq OWNER TO tak;

--
-- Name: properties_key_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.properties_key_id_seq OWNED BY public.properties_keys.id;


--
-- Name: properties_uid; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.properties_uid (
    id bigint NOT NULL,
    uid character varying(255) NOT NULL
);


ALTER TABLE public.properties_uid OWNER TO tak;

--
-- Name: properties_uid_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.properties_uid_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.properties_uid_id_seq OWNER TO tak;

--
-- Name: properties_uid_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.properties_uid_id_seq OWNED BY public.properties_uid.id;


--
-- Name: properties_value; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.properties_value (
    id bigint NOT NULL,
    properties_key_id bigint NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.properties_value OWNER TO tak;

--
-- Name: properties_value_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.properties_value_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.properties_value_id_seq OWNER TO tak;

--
-- Name: properties_value_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.properties_value_id_seq OWNED BY public.properties_value.id;


--
-- Name: resource_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.resource_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.resource_id_seq OWNER TO tak;

--
-- Name: resource_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.resource_id_seq OWNED BY public.resource.id;


--
-- Name: role; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.role (
    id bigint NOT NULL,
    role integer NOT NULL
);


ALTER TABLE public.role OWNER TO tak;

--
-- Name: role_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.role_id_seq OWNER TO tak;

--
-- Name: role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.role_id_seq OWNED BY public.role.id;


--
-- Name: role_permission; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.role_permission (
    role_id bigint NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.role_permission OWNER TO tak;

--
-- Name: schema_version; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.schema_version (
    installed_rank integer NOT NULL,
    version character varying(50),
    description character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    script character varying(1000) NOT NULL,
    checksum integer,
    installed_by character varying(100) NOT NULL,
    installed_on timestamp without time zone DEFAULT now() NOT NULL,
    execution_time integer NOT NULL,
    success boolean NOT NULL
);


ALTER TABLE public.schema_version OWNER TO tak;

--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.subscriptions (
    id integer NOT NULL,
    uid text,
    cot_msg text NOT NULL
);


ALTER TABLE public.subscriptions OWNER TO tak;

--
-- Name: subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.subscriptions_id_seq OWNER TO tak;

--
-- Name: subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.subscriptions_id_seq OWNED BY public.subscriptions.id;


--
-- Name: tak_user; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.tak_user (
    id bigint NOT NULL,
    token character varying(255) NOT NULL,
    user_name character varying(255) NOT NULL,
    email_address character varying(255) NOT NULL,
    first_name character varying(255),
    last_name character varying(255),
    phone_number character varying(255),
    organization character varying(255),
    state character varying(255),
    activated boolean DEFAULT false NOT NULL,
    groups bit varying
);


ALTER TABLE public.tak_user OWNER TO tak;

--
-- Name: tak_user_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.tak_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tak_user_id_seq OWNER TO tak;

--
-- Name: tak_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.tak_user_id_seq OWNED BY public.tak_user.id;


--
-- Name: video_connections; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.video_connections (
    id integer NOT NULL,
    created timestamp(3) with time zone DEFAULT now(),
    deleted boolean DEFAULT false,
    owner text,
    uuid text,
    url text,
    alias text,
    latitude text,
    longitude text,
    heading text,
    fov text,
    range text,
    type text,
    xml text,
    groups bit varying
);


ALTER TABLE public.video_connections OWNER TO tak;

--
-- Name: video_connection_id_seq; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.video_connection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.video_connection_id_seq OWNER TO tak;

--
-- Name: video_connection_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.video_connection_id_seq OWNED BY public.video_connections.id;


--
-- Name: video_connections_v2; Type: TABLE; Schema: public; Owner: tak
--

CREATE TABLE public.video_connections_v2 (
    id integer NOT NULL,
    uid text,
    active boolean DEFAULT true,
    alias text,
    thumbnail text,
    classification text,
    xml text,
    groups bit varying
);


ALTER TABLE public.video_connections_v2 OWNER TO tak;

--
-- Name: video_connection_id_seq_v2; Type: SEQUENCE; Schema: public; Owner: tak
--

CREATE SEQUENCE public.video_connection_id_seq_v2
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.video_connection_id_seq_v2 OWNER TO tak;

--
-- Name: video_connection_id_seq_v2; Type: SEQUENCE OWNED BY; Schema: public; Owner: tak
--

ALTER SEQUENCE public.video_connection_id_seq_v2 OWNED BY public.video_connections_v2.id;


--
-- Name: active_group_cache id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.active_group_cache ALTER COLUMN id SET DEFAULT nextval('public.active_group_cache_id_seq'::regclass);


--
-- Name: caveat id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.caveat ALTER COLUMN id SET DEFAULT nextval('public.caveat_id_seq'::regclass);


--
-- Name: ci_trap id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.ci_trap ALTER COLUMN id SET DEFAULT nextval('public.ci_trap_id_seq'::regclass);


--
-- Name: classification id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.classification ALTER COLUMN id SET DEFAULT nextval('public.classification_id_seq'::regclass);


--
-- Name: cot_image id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_image ALTER COLUMN id SET DEFAULT nextval('public.cot_image_id_seq'::regclass);


--
-- Name: cot_link id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_link ALTER COLUMN id SET DEFAULT nextval('public.cot_link_id_seq'::regclass);


--
-- Name: cot_router id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_router ALTER COLUMN id SET DEFAULT nextval('public.cot_router_id_seq'::regclass);


--
-- Name: cot_router_chat id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_router_chat ALTER COLUMN id SET DEFAULT nextval('public.cot_router_chat_id_seq'::regclass);


--
-- Name: cot_thumbnail id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_thumbnail ALTER COLUMN id SET DEFAULT nextval('public.cot_thumbnail_id_seq'::regclass);


--
-- Name: data_feed id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.data_feed ALTER COLUMN id SET DEFAULT nextval('public.data_feed_id_seq'::regclass);


--
-- Name: data_feed_type_pl id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.data_feed_type_pl ALTER COLUMN id SET DEFAULT nextval('public.data_feed_type_pl_id_seq'::regclass);


--
-- Name: device_profile id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.device_profile ALTER COLUMN id SET DEFAULT nextval('public.device_profile_id_seq'::regclass);


--
-- Name: device_profile_directory id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.device_profile_directory ALTER COLUMN id SET DEFAULT nextval('public.device_profile_directory_id_seq'::regclass);


--
-- Name: device_profile_file id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.device_profile_file ALTER COLUMN id SET DEFAULT nextval('public.device_profile_file_id_seq'::regclass);


--
-- Name: error_logs id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.error_logs ALTER COLUMN id SET DEFAULT nextval('public.error_logs_id_seq'::regclass);


--
-- Name: fed_event_kind_pl id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.fed_event_kind_pl ALTER COLUMN id SET DEFAULT nextval('public.fed_event_kind_pl_id_seq'::regclass);


--
-- Name: group_type_pl id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.group_type_pl ALTER COLUMN id SET DEFAULT nextval('public.group_type_pl_id_seq'::regclass);


--
-- Name: groups id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.groups ALTER COLUMN id SET DEFAULT nextval('public.groups_id_seq'::regclass);


--
-- Name: icon id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.icon ALTER COLUMN id SET DEFAULT nextval('public.icon_id_seq'::regclass);


--
-- Name: iconset id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.iconset ALTER COLUMN id SET DEFAULT nextval('public.iconset_id_seq'::regclass);


--
-- Name: maplayer id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.maplayer ALTER COLUMN id SET DEFAULT nextval('public.maplayer_id_seq'::regclass);


--
-- Name: mission id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission ALTER COLUMN id SET DEFAULT nextval('public.mission_id_seq'::regclass);


--
-- Name: mission_resource_keyword id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_resource_keyword ALTER COLUMN id SET DEFAULT nextval('public.mission_resource_keyword_id_seq'::regclass);


--
-- Name: mission_uid_keyword id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_uid_keyword ALTER COLUMN id SET DEFAULT nextval('public.mission_uid_keyword_id_seq'::regclass);


--
-- Name: permission id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.permission ALTER COLUMN id SET DEFAULT nextval('public.permission_id_seq'::regclass);


--
-- Name: properties_keys id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.properties_keys ALTER COLUMN id SET DEFAULT nextval('public.properties_key_id_seq'::regclass);


--
-- Name: properties_uid id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.properties_uid ALTER COLUMN id SET DEFAULT nextval('public.properties_uid_id_seq'::regclass);


--
-- Name: properties_value id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.properties_value ALTER COLUMN id SET DEFAULT nextval('public.properties_value_id_seq'::regclass);


--
-- Name: resource id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.resource ALTER COLUMN id SET DEFAULT nextval('public.resource_id_seq'::regclass);


--
-- Name: role id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.role ALTER COLUMN id SET DEFAULT nextval('public.role_id_seq'::regclass);


--
-- Name: subscriptions id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.subscriptions ALTER COLUMN id SET DEFAULT nextval('public.subscriptions_id_seq'::regclass);


--
-- Name: tak_user id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.tak_user ALTER COLUMN id SET DEFAULT nextval('public.tak_user_id_seq'::regclass);


--
-- Name: video_connections id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.video_connections ALTER COLUMN id SET DEFAULT nextval('public.video_connection_id_seq'::regclass);


--
-- Name: video_connections_v2 id; Type: DEFAULT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.video_connections_v2 ALTER COLUMN id SET DEFAULT nextval('public.video_connection_id_seq_v2'::regclass);


--
-- Data for Name: active_group_cache; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.active_group_cache (id, username, groupname, direction, enabled) FROM stdin;
\.


--
-- Data for Name: caveat; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.caveat (id, name) FROM stdin;
\.


--
-- Data for Name: certificate; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.certificate (id, creator_dn, subject_dn, user_dn, issuance_date, effective_date, expiration_date, revocation_date, certificate, hash, client_uid, token) FROM stdin;
\.


--
-- Data for Name: certificate_private_key; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.certificate_private_key (certificate_id, key_format_code, key) FROM stdin;
\.


--
-- Data for Name: ci_trap; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.ci_trap (id, type, user_callsign, user_description, date_time, date_time_description, location_description, event_scale, importance, uid, location, hash, xml, groups, title) FROM stdin;
\.


--
-- Data for Name: classification; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.classification (id, level) FROM stdin;
\.


--
-- Data for Name: classification_caveat; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.classification_caveat (classification_id, caveat_id) FROM stdin;
\.


--
-- Data for Name: client_endpoint; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.client_endpoint (id, callsign, uid, username) FROM stdin;
\.


--
-- Data for Name: client_endpoint_event; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.client_endpoint_event (id, client_endpoint_id, connection_event_type_id, created_ts, client_version, groups) FROM stdin;
\.


--
-- Data for Name: clientdetails; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.clientdetails (appid, resourceids, appsecret, scope, granttypes, redirecturl, authorities, access_token_validity, refresh_token_validity, additionalinformation, autoapprovescopes) FROM stdin;
\.


--
-- Data for Name: connection_event_type; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.connection_event_type (id, event_name) FROM stdin;
1	Connected
2	Disconnected
\.


--
-- Data for Name: cot_image; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.cot_image (id, image, cot_id) FROM stdin;
\.


--
-- Data for Name: cot_link; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.cot_link (id, containing_event, target_uid, target_type, relation, url, remarks, mime_type, version) FROM stdin;
\.


--
-- Data for Name: cot_router; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.cot_router (id, uid, cot_type, access, qos, opex, start, "time", stale, how, point_hae, point_ce, point_le, detail, servertime, servertime_hour, event_pt, groups, caveat, releaseableto) FROM stdin;
\.


--
-- Data for Name: cot_router_chat; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.cot_router_chat (id, uid, cot_type, access, qos, opex, start, "time", stale, how, point_hae, point_ce, point_le, groups, detail, servertime, sender_callsign, dest_callsign, dest_uid, chat_content, chat_room, event_pt) FROM stdin;
\.


--
-- Data for Name: cot_thumbnail; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.cot_thumbnail (id, thumbnail, cot_id, cot_image_id) FROM stdin;
\.


--
-- Data for Name: data_feed; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.data_feed (id, uuid, name, type, auth, port, auth_required, protocol, feed_group, iface, archive, anongroup, sync, archive_only, core_version, core_version_tls_versions, groups, sync_cache_retention_seconds, federated, binary_payload_websocket_only, predicate_lang, data_source_endpoint, predicate, auth_type) FROM stdin;
\.


--
-- Data for Name: data_feed_cot; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.data_feed_cot (cot_router_id, data_feed_id) FROM stdin;
\.


--
-- Data for Name: data_feed_filter_group; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.data_feed_filter_group (data_feed_id, filter_group) FROM stdin;
\.


--
-- Data for Name: data_feed_tag; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.data_feed_tag (data_feed_id, tag) FROM stdin;
\.


--
-- Data for Name: data_feed_type_pl; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.data_feed_type_pl (id, feed_type) FROM stdin;
1	Streaming
2	API
3	Plugin
4	Predicate
\.


--
-- Data for Name: device_profile; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.device_profile (id, name, groups, apply_on_enrollment, apply_on_connect, active, updated, tool) FROM stdin;
\.


--
-- Data for Name: device_profile_directory; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.device_profile_directory (id, path, device_profile_id) FROM stdin;
\.


--
-- Data for Name: device_profile_file; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.device_profile_file (id, name, data, device_profile_id) FROM stdin;
\.


--
-- Data for Name: error_logs; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.error_logs (id, uid, callsign, log, "time", filename, major_version, minor_version, platform, contents) FROM stdin;
\.


--
-- Data for Name: fed_event; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.fed_event (fed_id, fed_name, event_kind_id, event_time, remote, details) FROM stdin;
\.


--
-- Data for Name: fed_event_kind_pl; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.fed_event_kind_pl (id, event_kind) FROM stdin;
1	connect
2	disconnect
3	send-changes
\.


--
-- Data for Name: group_bitpos_sequence; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.group_bitpos_sequence (bitpos) FROM stdin;
0
\.


--
-- Data for Name: group_type_pl; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.group_type_pl (id, type) FROM stdin;
1	LDAP
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.groups (id, name, bitpos, create_ts, type) FROM stdin;
\.


--
-- Data for Name: icon; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.icon (id, bytes, group_name, iconsetuid, mimetype, name, type2525b, iconset_id, created) FROM stdin;
\.


--
-- Data for Name: iconset; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.iconset (id, defaultfriendly, defaulthostile, defaultunknown, name, skipresize, uid, version, created) FROM stdin;
\.


--
-- Data for Name: maplayer; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.maplayer (id, create_time, modified_time, uid, creator_uid, name, description, type, url, default_layer, enabled, min_zoom, max_zoom, tile_type, server_parts, background_color, tile_update, ignore_errors, invert_y_coordinate, mission_id, north, south, east, west, additional_parameters, coordinate_system, version, opacity, layers, path, after) FROM stdin;
\.


--
-- Data for Name: mission; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission (id, name, creatoruid, create_change_id, create_time, tool, groups, chatroom, description, parent_mission_id, password_hash, default_role_id, expiration, base_layer, bbox, path, classification, last_edited, bounding_polygon, invite_only, guid) FROM stdin;
1	exchecktemplates	ExCheck	\N	2023-10-21 16:17:38.467+00	ExCheck	1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111	\N	\N	\N	\N	\N	-1	\N	\N	\N	\N	\N	\N	f	\N
2	citrap	CITrapReportService	\N	2023-10-21 16:17:38.467+00	citrap	1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111	\N	\N	\N	\N	\N	-1	\N	\N	\N	\N	\N	\N	f	\N
\.


--
-- Data for Name: mission_change; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_change (id, hash, uid, mission_name, ts, change_type, mission_id, creatoruid, external_data_token, external_data_name, external_data_tool, external_data_uid, external_data_notes, servertime, mission_feed_uid, map_layer_uid, remote_federated_change) FROM stdin;
\.


--
-- Data for Name: mission_external_data; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_external_data (id, name, tool, url_data, url_display, mission_id, notes) FROM stdin;
\.


--
-- Data for Name: mission_feed; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_feed (uid, data_feed_uid, filter_polygon, filter_cot_types, filter_callsign, mission_id) FROM stdin;
\.


--
-- Data for Name: mission_invitation; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_invitation (id, mission_name, invitee, type, creator_uid, create_time, token, role_id, mission_id) FROM stdin;
\.


--
-- Data for Name: mission_keyword; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_keyword (mission_id, keyword) FROM stdin;
\.


--
-- Data for Name: mission_layer; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_layer (uid, name, type, parent_node_uid, mission_id, after) FROM stdin;
\.


--
-- Data for Name: mission_log; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_log (id, content, creator_uid, dtg, entry_uid, servertime, created) FROM stdin;
\.


--
-- Data for Name: mission_log_hash; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_log_hash (mission_log_id, contenthashes) FROM stdin;
\.


--
-- Data for Name: mission_log_keyword; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_log_keyword (mission_log_id, keyword) FROM stdin;
\.


--
-- Data for Name: mission_log_mission_name; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_log_mission_name (mission_log_id, missionnames) FROM stdin;
\.


--
-- Data for Name: mission_resource; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_resource (mission_id, resource_id, resource_hash) FROM stdin;
\.


--
-- Data for Name: mission_resource_keyword; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_resource_keyword (id, mission_id, hash, keyword) FROM stdin;
\.


--
-- Data for Name: mission_subscription; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_subscription (mission_id, client_uid, create_time, uid, token, role_id, username) FROM stdin;
\.


--
-- Data for Name: mission_uid; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_uid (mission_id, uid) FROM stdin;
\.


--
-- Data for Name: mission_uid_keyword; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.mission_uid_keyword (id, mission_id, uid, keyword) FROM stdin;
\.


--
-- Data for Name: oauth_access_token; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.oauth_access_token (token_id, token, authentication_id, user_name, client_id, authentication, refresh_token) FROM stdin;
\.


--
-- Data for Name: oauth_approvals; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.oauth_approvals (userid, clientid, scope, status, expiresat, lastmodifiedat) FROM stdin;
\.


--
-- Data for Name: oauth_client_details; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.oauth_client_details (client_id, resource_ids, client_secret, scope, authorized_grant_types, web_server_redirect_uri, authorities, access_token_validity, refresh_token_validity, additional_information, autoapprove) FROM stdin;
\.


--
-- Data for Name: oauth_client_token; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.oauth_client_token (token_id, token, authentication_id, user_name, client_id) FROM stdin;
\.


--
-- Data for Name: oauth_code; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.oauth_code (code, authentication) FROM stdin;
\.


--
-- Data for Name: oauth_refresh_token; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.oauth_refresh_token (token_id, token, authentication) FROM stdin;
\.


--
-- Data for Name: permission; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.permission (id, permission) FROM stdin;
1	0
2	1
3	2
4	3
5	4
6	5
7	6
8	7
\.


--
-- Data for Name: properties_keys; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.properties_keys (id, properties_uid_id, key) FROM stdin;
\.


--
-- Data for Name: properties_uid; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.properties_uid (id, uid) FROM stdin;
\.


--
-- Data for Name: properties_value; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.properties_value (id, properties_key_id, value) FROM stdin;
\.


--
-- Data for Name: resource; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.resource (id, altitude, data, filename, keywords, location, mimetype, name, permissions, remarks, submissiontime, submitter, uid, hash, creatoruid, tool, groups, expiration) FROM stdin;
\.


--
-- Data for Name: role; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.role (id, role) FROM stdin;
1	0
2	1
3	2
\.


--
-- Data for Name: role_permission; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.role_permission (role_id, permission_id) FROM stdin;
1	1
1	2
1	3
1	4
1	5
2	1
2	2
3	1
1	6
1	7
1	8
\.


--
-- Data for Name: schema_version; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.schema_version (installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) FROM stdin;
1	7	create base schema	SQL	V7__create_base_schema.sql	1620613293	postgres	2023-10-21 16:17:36.027603	1019	t
2	8	convert timestamps to use time zone	SQL	V8__convert_timestamps_to_use_time_zone.sql	937814473	postgres	2023-10-21 16:17:37.128979	321	t
3	9	create resource hash	SQL	V9__create_resource_hash.sql	-1676016357	postgres	2023-10-21 16:17:37.505001	22	t
4	10	update resource hash	SQL	V10__update_resource_hash.sql	-1681566080	postgres	2023-10-21 16:17:37.547367	4	t
5	11	create video connections table	SQL	V11__create_video_connections_table.sql	-328906493	postgres	2023-10-21 16:17:37.568905	22	t
6	12	mission api tables	SQL	V12__mission_api_tables.sql	-1432616410	postgres	2023-10-21 16:17:37.610804	84	t
7	13	contact api tables	SQL	V13__contact_api_tables.sql	-420378487	postgres	2023-10-21 16:17:37.740528	50	t
8	14	mission log tables	SQL	V14__mission_log_tables.sql	-591840626	postgres	2023-10-21 16:17:37.80896	45	t
9	15	resource add creatorUid	SQL	V15__resource_add_creatorUid.sql	1197298780	postgres	2023-10-21 16:17:37.869098	7	t
10	16	add mission log keyword add client version	SQL	V16__add_mission_log_keyword_add_client_version.sql	-820888220	postgres	2023-10-21 16:17:37.888579	17	t
11	17	change creator name	SQL	V17__change_creator_name.sql	1752396087	postgres	2023-10-21 16:17:37.920131	11	t
12	18	errorlog mission groups	SQL	V18__errorlog_mission_groups.sql	-899327526	postgres	2023-10-21 16:17:37.949742	60	t
13	19	mission group citrap	SQL	V19__mission_group_citrap.sql	1646130550	postgres	2023-10-21 16:17:38.027504	38	t
14	20	mission add parent	SQL	V20__mission_add_parent.sql	781775663	postgres	2023-10-21 16:17:38.083182	4	t
15	21	latestresource add tool	SQL	V21__latestresource_add_tool.sql	-34543300	postgres	2023-10-21 16:17:38.099585	5	t
16	22	latestresource add tool	SQL	V22__latestresource_add_tool.sql	-1112696781	postgres	2023-10-21 16:17:38.113752	5	t
17	23	backfill tool	SQL	V23__backfill_tool.sql	761101564	postgres	2023-10-21 16:17:38.128303	5	t
18	24	certificate	SQL	V24__certificate.sql	1408073105	postgres	2023-10-21 16:17:38.144175	31	t
19	25	certificate client uid	SQL	V25__certificate_client_uid.sql	-220528613	postgres	2023-10-21 16:17:38.194046	3	t
20	26	device profile	SQL	V26__device_profile.sql	494937717	postgres	2023-10-21 16:17:38.209261	46	t
21	27	maplayer api tables	SQL	V27__maplayer_api_tables.sql	248583611	postgres	2023-10-21 16:17:38.270311	23	t
22	28	add mission external data	SQL	V28__add_mission_external_data.sql	-1399956893	postgres	2023-10-21 16:17:38.343162	10	t
23	29	profile add tool	SQL	V29__profile_add_tool.sql	-311302037	postgres	2023-10-21 16:17:38.366047	3	t
24	30	mission external data mission change add notes	SQL	V30__mission_external_data_mission_change_add_notes.sql	383181011	postgres	2023-10-21 16:17:38.380638	4	t
25	31	data sync phase2	SQL	V31__data_sync_phase2.sql	891535701	postgres	2023-10-21 16:17:38.396822	17	t
26	32	profile add directory	SQL	V32__profile_add_directory.sql	-164769237	postgres	2023-10-21 16:17:38.427987	14	t
27	33	data sync phase3	SQL	V33__data_sync_phase3.sql	1806985463	postgres	2023-10-21 16:17:38.455062	95	t
28	34	spring oauth2	SQL	V34__spring_oauth2.sql	582011789	postgres	2023-10-21 16:17:38.56837	56	t
29	35	user management	SQL	V35__user_management.sql	-375392813	postgres	2023-10-21 16:17:38.638876	27	t
30	36	add federate event	SQL	V36__add_federate_event.sql	1506539097	postgres	2023-10-21 16:17:38.681423	38	t
31	37	data sync add permission	SQL	V37__data_sync_add_permission.sql	-1902268977	postgres	2023-10-21 16:17:38.734719	8	t
32	38	user management add groups	SQL	V38__user_management_add_groups.sql	-1059591275	postgres	2023-10-21 16:17:38.756366	4	t
33	39	add mission api indices	SQL	V39__add_mission_api_indices.sql	1408777471	postgres	2023-10-21 16:17:38.771732	16	t
34	40	add mfdt federation event	SQL	V40__add_mfdt_federation_event.sql	-1750110284	postgres	2023-10-21 16:17:38.802824	2	t
35	41	client endpoint event add groups	SQL	V41__client_endpoint_event_add_groups.sql	-1596965984	postgres	2023-10-21 16:17:38.816165	8	t
36	42	add mission expiration resource expiration	SQL	V42__add_mission_expiration_resource_expiration.sql	1466425663	postgres	2023-10-21 16:17:38.836028	11	t
37	43	add cot router chat	SQL	V43__add_cot_router_chat.sql	1767927301	postgres	2023-10-21 16:17:38.857793	87	t
38	44	active group cache	SQL	V44__active_group_cache.sql	712939816	postgres	2023-10-21 16:17:38.959425	15	t
39	45	video connections add groups	SQL	V45__video_connections_add_groups.sql	1292705315	postgres	2023-10-21 16:17:38.985644	4	t
40	46	create video connections table v2	SQL	V46__create_video_connections_table_v2.sql	-1663354284	postgres	2023-10-21 16:17:39.002656	15	t
41	47	add cop attributes to mission	SQL	V47__add_cop_attributes_to_mission.sql	80107221	postgres	2023-10-21 16:17:39.030107	10	t
42	48	data sync add feed permission	SQL	V48__data_sync_add_feed_permission.sql	1668166169	postgres	2023-10-21 16:17:39.052209	4	t
43	49	certificate add token	SQL	V49__certificate_add_token.sql	-1396359276	postgres	2023-10-21 16:17:39.065894	2	t
44	50	cop hierarchy and classification	SQL	V50__cop_hierarchy_and_classification.sql	-90778482	postgres	2023-10-21 16:17:39.075574	3	t
45	51	data feed cot	SQL	V51__data_feed_cot.sql	1384074560	postgres	2023-10-21 16:17:39.088964	43	t
46	52	add username to mission subscription	SQL	V52__add_username_to_mission_subscription.sql	70618965	postgres	2023-10-21 16:17:39.143587	10	t
47	53	add map layers to mission	SQL	V53__add_map_layers_to_mission.sql	1958097757	postgres	2023-10-21 16:17:39.163596	5	t
48	54	add group compare function	SQL	V54__add_group_compare_function.sql	-119822839	postgres	2023-10-21 16:17:39.178992	3	t
49	55	add feeds and maplayers to changes	SQL	V55__add_feeds_and_maplayers_to_changes.sql	-705916174	postgres	2023-10-21 16:17:39.190346	5	t
50	56	add last edited to mission	SQL	V56__add_last_edited_to_mission.sql	895065823	postgres	2023-10-21 16:17:39.206236	4	t
51	57	add attributes to maplayer	SQL	V57__add_attributes_to_maplayer.sql	417741404	postgres	2023-10-21 16:17:39.22303	11	t
52	58	drop mission subscription pkey	SQL	V58__drop_mission_subscription_pkey.sql	206796055	postgres	2023-10-21 16:17:39.248365	3	t
53	59	mission polygon	SQL	V59__mission_polygon.sql	-2053006512	postgres	2023-10-21 16:17:39.266371	2	t
54	60	change layers to string	SQL	V60__change_layers_to_string.sql	-550271480	postgres	2023-10-21 16:17:39.278202	3	t
55	61	add content to error logs	SQL	V61__add_content_to_error_logs.sql	-537370332	postgres	2023-10-21 16:17:39.290594	4	t
56	62	change feed group to bit	SQL	V62__change_feed_group_to_bit.sql	-64874116	postgres	2023-10-21 16:17:39.306426	7	t
57	63	cleanup client endpoint index	SQL	V63__cleanup_client_endpoint_index.sql	-178055914	postgres	2023-10-21 16:17:39.324951	4	t
58	64	data feed tags and filter groups function	SQL	V64__data_feed_tags_and_filter_groups_function.sql	-1381904641	postgres	2023-10-21 16:17:39.347603	6	t
59	65	resource allow null hash	SQL	V65__resource_allow_null_hash.sql	-191552586	postgres	2023-10-21 16:17:39.404238	4	t
60	66	resource allow null uid	SQL	V66__resource_allow_null_uid.sql	-1626517235	postgres	2023-10-21 16:17:39.42149	5	t
61	67	add classification and caveat	SQL	V67__add_classification_and_caveat.sql	2140261	postgres	2023-10-21 16:17:39.440031	57	t
62	68	data feed latest sa	SQL	V68__data_feed_latest_sa.sql	-2092688013	postgres	2023-10-21 16:17:39.515117	2	t
63	69	update classification and caveat	SQL	V69__update_classification_and_caveat.sql	1590324977	postgres	2023-10-21 16:17:39.526197	8	t
64	70	add mission subscription unique constraint	SQL	V70__add_mission_subscription_unique_constraint.sql	-1580614143	postgres	2023-10-21 16:17:39.542167	15	t
65	71	add federated column to data feed	SQL	V71__add_federated_column_to_data_feed.sql	309547282	postgres	2023-10-21 16:17:39.570503	5	t
66	72	add invite only to mission	SQL	V72__add_invite_only_to_mission.sql	38960504	postgres	2023-10-21 16:17:39.588266	5	t
67	73	mission layer	SQL	V73__mission_layer.sql	240208539	postgres	2023-10-21 16:17:39.604395	11	t
68	74	add binary payload websocket only to data feed	SQL	V74__add_binary_payload_websocket_only_to_data_feed.sql	713367145	postgres	2023-10-21 16:17:39.625394	4	t
69	75	add mission guid	SQL	V75__add_mission_guid.sql	-579844343	postgres	2023-10-21 16:17:39.639482	12	t
70	76	mission invitation add mission id and backport	SQL	V76__mission_invitation_add_mission_id_and_backport.sql	-691012732	postgres	2023-10-21 16:17:39.661052	6	t
71	77	add properties table	SQL	V77__add_properties_table.sql	-1374733905	postgres	2023-10-21 16:17:39.676936	59	t
72	78	mission layer updates	SQL	V78__mission_layer_updates.sql	568814549	postgres	2023-10-21 16:17:39.750752	3	t
73	79	mission change cleanup	SQL	V79__mission_change_cleanup.sql	-222343372	postgres	2023-10-21 16:17:39.764399	4	t
74	80	remove mission name unique constraint	SQL	V80__remove_mission_name_unique_constraint.sql	-1192044784	postgres	2023-10-21 16:17:39.781403	4	t
75	81	mission layer add constraints	SQL	V81__mission_layer_add_constraints.sql	-1197119295	postgres	2023-10-21 16:17:39.801393	12	t
76	82	mission layer remove constraints	SQL	V82__mission_layer_remove_constraints.sql	1438553058	postgres	2023-10-21 16:17:39.826261	4	t
77	83	add federated status to mission change	SQL	V83__add_federated_status_to_mission_change.sql	-228556935	postgres	2023-10-21 16:17:39.843895	3	t
78	84	predicate data feeds	SQL	V84__predicate_data_feeds.sql	-469728121	postgres	2023-10-21 16:17:39.859576	12	t
79	85	change column name in table mission feed	SQL	V85__change_column_name_in_table_mission_feed.sql	271575648	postgres	2023-10-21 16:17:39.883818	4	t
80	86	change column name in table mission feed 2	SQL	V86__change_column_name_in_table_mission_feed_2.sql	1068144947	postgres	2023-10-21 16:17:39.899102	2	t
81	87	add caveat releaseableTo columns in table cot router	SQL	V87__add_caveat_releaseableTo_columns_in_table_cot_router.sql	-1799344599	postgres	2023-10-21 16:17:39.910667	2	t
82	\N	remove schema version function	SQL	R__remove_schema_version_function.sql	1770950903	postgres	2023-10-21 16:17:39.920635	2	t
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: subscriptions; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.subscriptions (id, uid, cot_msg) FROM stdin;
\.


--
-- Data for Name: tak_user; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.tak_user (id, token, user_name, email_address, first_name, last_name, phone_number, organization, state, activated, groups) FROM stdin;
\.


--
-- Data for Name: video_connections; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.video_connections (id, created, deleted, owner, uuid, url, alias, latitude, longitude, heading, fov, range, type, xml, groups) FROM stdin;
\.


--
-- Data for Name: video_connections_v2; Type: TABLE DATA; Schema: public; Owner: tak
--

COPY public.video_connections_v2 (id, uid, active, alias, thumbnail, classification, xml, groups) FROM stdin;
\.


--
-- Name: active_group_cache_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.active_group_cache_id_seq', 1, false);


--
-- Name: caveat_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.caveat_id_seq', 1, false);


--
-- Name: certificate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.certificate_id_seq', 1, false);


--
-- Name: ci_trap_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.ci_trap_id_seq', 1, false);


--
-- Name: classification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.classification_id_seq', 1, false);


--
-- Name: client_endpoint_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.client_endpoint_event_id_seq', 1, false);


--
-- Name: client_endpoint_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.client_endpoint_id_seq', 1, false);


--
-- Name: connection_event_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.connection_event_type_id_seq', 2, true);


--
-- Name: cot_image_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.cot_image_id_seq', 1, false);


--
-- Name: cot_image_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.cot_image_seq', 101, false);


--
-- Name: cot_link_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.cot_link_id_seq', 1, false);


--
-- Name: cot_router_chat_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.cot_router_chat_id_seq', 1, false);


--
-- Name: cot_router_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.cot_router_id_seq', 1, false);


--
-- Name: cot_router_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.cot_router_seq', 101, false);


--
-- Name: cot_thumbnail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.cot_thumbnail_id_seq', 1, false);


--
-- Name: cot_thumbnail_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.cot_thumbnail_seq', 101, false);


--
-- Name: data_feed_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.data_feed_id_seq', 1, false);


--
-- Name: data_feed_type_pl_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.data_feed_type_pl_id_seq', 4, true);


--
-- Name: device_profile_directory_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.device_profile_directory_id_seq', 1, false);


--
-- Name: device_profile_file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.device_profile_file_id_seq', 1, false);


--
-- Name: device_profile_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.device_profile_id_seq', 1, false);


--
-- Name: error_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.error_logs_id_seq', 1, false);


--
-- Name: fed_event_kind_pl_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.fed_event_kind_pl_id_seq', 3, true);


--
-- Name: group_type_pl_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.group_type_pl_id_seq', 1, true);


--
-- Name: groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.groups_id_seq', 1, false);


--
-- Name: icon_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.icon_id_seq', 1, false);


--
-- Name: iconset_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.iconset_id_seq', 1, false);


--
-- Name: maplayer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.maplayer_id_seq', 1, false);


--
-- Name: mission_change_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.mission_change_id_seq', 1, false);


--
-- Name: mission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.mission_id_seq', 2, true);


--
-- Name: mission_invitation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.mission_invitation_id_seq', 7602, false);


--
-- Name: mission_resource_keyword_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.mission_resource_keyword_id_seq', 1, false);


--
-- Name: mission_uid_keyword_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.mission_uid_keyword_id_seq', 1, false);


--
-- Name: permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.permission_id_seq', 8, true);


--
-- Name: properties_key_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.properties_key_id_seq', 1, false);


--
-- Name: properties_uid_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.properties_uid_id_seq', 1, false);


--
-- Name: properties_value_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.properties_value_id_seq', 1, false);


--
-- Name: resource_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.resource_id_seq', 1, false);


--
-- Name: role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.role_id_seq', 3, true);


--
-- Name: subscriptions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.subscriptions_id_seq', 1, false);


--
-- Name: tak_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.tak_user_id_seq', 1, false);


--
-- Name: video_connection_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.video_connection_id_seq', 1, false);


--
-- Name: video_connection_id_seq_v2; Type: SEQUENCE SET; Schema: public; Owner: tak
--

SELECT pg_catalog.setval('public.video_connection_id_seq_v2', 1, false);


--
-- Name: active_group_cache active_group_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.active_group_cache
    ADD CONSTRAINT active_group_cache_pkey PRIMARY KEY (id);


--
-- Name: caveat caveat_id_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.caveat
    ADD CONSTRAINT caveat_id_key UNIQUE (id);


--
-- Name: caveat caveat_name_unique; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.caveat
    ADD CONSTRAINT caveat_name_unique UNIQUE (name);


--
-- Name: caveat caveat_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.caveat
    ADD CONSTRAINT caveat_pkey PRIMARY KEY (id);


--
-- Name: certificate certificate_pk; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.certificate
    ADD CONSTRAINT certificate_pk PRIMARY KEY (id);


--
-- Name: certificate_private_key certificate_private_key_key_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.certificate_private_key
    ADD CONSTRAINT certificate_private_key_key_key UNIQUE (key);


--
-- Name: certificate_private_key certificate_private_key_pk; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.certificate_private_key
    ADD CONSTRAINT certificate_private_key_pk PRIMARY KEY (certificate_id);


--
-- Name: ci_trap ci_trap_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.ci_trap
    ADD CONSTRAINT ci_trap_pkey PRIMARY KEY (id);


--
-- Name: classification_caveat classification_caveat_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.classification_caveat
    ADD CONSTRAINT classification_caveat_pkey PRIMARY KEY (classification_id, caveat_id);


--
-- Name: classification classification_id_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.classification
    ADD CONSTRAINT classification_id_key UNIQUE (id);


--
-- Name: classification classification_level_unique; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.classification
    ADD CONSTRAINT classification_level_unique UNIQUE (level);


--
-- Name: classification classification_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.classification
    ADD CONSTRAINT classification_pkey PRIMARY KEY (id);


--
-- Name: client_endpoint_event client_endpoint_event_pk; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.client_endpoint_event
    ADD CONSTRAINT client_endpoint_event_pk PRIMARY KEY (id);


--
-- Name: client_endpoint client_endpoint_pk; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.client_endpoint
    ADD CONSTRAINT client_endpoint_pk PRIMARY KEY (id);


--
-- Name: clientdetails clientdetails_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.clientdetails
    ADD CONSTRAINT clientdetails_pkey PRIMARY KEY (appid);


--
-- Name: connection_event_type connection_event_type_event_name_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.connection_event_type
    ADD CONSTRAINT connection_event_type_event_name_key UNIQUE (event_name);


--
-- Name: connection_event_type connection_event_type_pk; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.connection_event_type
    ADD CONSTRAINT connection_event_type_pk PRIMARY KEY (id);


--
-- Name: cot_image cot_image_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_image
    ADD CONSTRAINT cot_image_pkey PRIMARY KEY (id);


--
-- Name: cot_link cot_link_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_link
    ADD CONSTRAINT cot_link_pkey PRIMARY KEY (id);


--
-- Name: cot_router_chat cot_router_chat_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_router_chat
    ADD CONSTRAINT cot_router_chat_pkey PRIMARY KEY (id);


--
-- Name: cot_router cot_router_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_router
    ADD CONSTRAINT cot_router_pkey PRIMARY KEY (id);


--
-- Name: cot_thumbnail cot_thumbnail_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_thumbnail
    ADD CONSTRAINT cot_thumbnail_pkey PRIMARY KEY (id);


--
-- Name: data_feed_filter_group data_feed_filter_group_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.data_feed_filter_group
    ADD CONSTRAINT data_feed_filter_group_pkey PRIMARY KEY (data_feed_id, filter_group);


--
-- Name: data_feed data_feed_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.data_feed
    ADD CONSTRAINT data_feed_pkey PRIMARY KEY (id);


--
-- Name: data_feed_tag data_feed_tag_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.data_feed_tag
    ADD CONSTRAINT data_feed_tag_pkey PRIMARY KEY (data_feed_id, tag);


--
-- Name: data_feed_type_pl data_feed_type_pl_feed_type_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.data_feed_type_pl
    ADD CONSTRAINT data_feed_type_pl_feed_type_key UNIQUE (feed_type);


--
-- Name: data_feed_type_pl data_feed_type_pl_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.data_feed_type_pl
    ADD CONSTRAINT data_feed_type_pl_pkey PRIMARY KEY (id);


--
-- Name: data_feed data_feed_uuid_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.data_feed
    ADD CONSTRAINT data_feed_uuid_key UNIQUE (uuid);


--
-- Name: device_profile_directory device_profile_directory_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.device_profile_directory
    ADD CONSTRAINT device_profile_directory_pkey PRIMARY KEY (id);


--
-- Name: device_profile_file device_profile_file_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.device_profile_file
    ADD CONSTRAINT device_profile_file_pkey PRIMARY KEY (id);


--
-- Name: device_profile device_profile_name_unique; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.device_profile
    ADD CONSTRAINT device_profile_name_unique UNIQUE (name);


--
-- Name: device_profile device_profile_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.device_profile
    ADD CONSTRAINT device_profile_pkey PRIMARY KEY (id);


--
-- Name: error_logs error_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.error_logs
    ADD CONSTRAINT error_logs_pkey PRIMARY KEY (id);


--
-- Name: fed_event_kind_pl fed_event_kind_pl_event_kind_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.fed_event_kind_pl
    ADD CONSTRAINT fed_event_kind_pl_event_kind_key UNIQUE (event_kind);


--
-- Name: fed_event_kind_pl fed_event_kind_pl_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.fed_event_kind_pl
    ADD CONSTRAINT fed_event_kind_pl_pkey PRIMARY KEY (id);


--
-- Name: fed_event fed_event_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.fed_event
    ADD CONSTRAINT fed_event_pkey PRIMARY KEY (fed_id, fed_name, event_kind_id, event_time);


--
-- Name: group_bitpos_sequence group_bitpos_sequence_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.group_bitpos_sequence
    ADD CONSTRAINT group_bitpos_sequence_pkey PRIMARY KEY (bitpos);


--
-- Name: group_type_pl group_type_pl_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.group_type_pl
    ADD CONSTRAINT group_type_pl_pkey PRIMARY KEY (id);


--
-- Name: group_type_pl group_type_pl_type_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.group_type_pl
    ADD CONSTRAINT group_type_pl_type_key UNIQUE (type);


--
-- Name: groups groups_bitpos_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_bitpos_key UNIQUE (bitpos);


--
-- Name: groups groups_name_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_name_key UNIQUE (name);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: icon icon_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.icon
    ADD CONSTRAINT icon_pkey PRIMARY KEY (id);


--
-- Name: iconset iconset_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.iconset
    ADD CONSTRAINT iconset_pkey PRIMARY KEY (id);


--
-- Name: iconset iconset_uid_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.iconset
    ADD CONSTRAINT iconset_uid_key UNIQUE (uid);


--
-- Name: maplayer maplayer_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.maplayer
    ADD CONSTRAINT maplayer_pkey PRIMARY KEY (id);


--
-- Name: mission_change mission_change_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_change
    ADD CONSTRAINT mission_change_pkey PRIMARY KEY (id);


--
-- Name: mission_invitation mission_invitation_mission_name_invitee_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_invitation
    ADD CONSTRAINT mission_invitation_mission_name_invitee_key UNIQUE (mission_name, invitee);


--
-- Name: mission_invitation mission_invitation_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_invitation
    ADD CONSTRAINT mission_invitation_pkey PRIMARY KEY (id);


--
-- Name: mission_keyword mission_keyword_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_keyword
    ADD CONSTRAINT mission_keyword_pkey PRIMARY KEY (mission_id, keyword);


--
-- Name: mission_log_hash mission_log_hash_pk; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_log_hash
    ADD CONSTRAINT mission_log_hash_pk PRIMARY KEY (mission_log_id, contenthashes);


--
-- Name: mission_log_keyword mission_log_keyword_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_log_keyword
    ADD CONSTRAINT mission_log_keyword_pkey PRIMARY KEY (mission_log_id, keyword);


--
-- Name: mission_log_mission_name mission_log_mission_name_pk; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_log_mission_name
    ADD CONSTRAINT mission_log_mission_name_pk PRIMARY KEY (mission_log_id, missionnames);


--
-- Name: mission_log mission_log_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_log
    ADD CONSTRAINT mission_log_pkey PRIMARY KEY (id);


--
-- Name: mission mission_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission
    ADD CONSTRAINT mission_pkey PRIMARY KEY (id);


--
-- Name: mission_resource_keyword mission_resource_keyword_id_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_resource_keyword
    ADD CONSTRAINT mission_resource_keyword_id_key UNIQUE (id);


--
-- Name: mission_resource_keyword mission_resource_keyword_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_resource_keyword
    ADD CONSTRAINT mission_resource_keyword_pkey PRIMARY KEY (id);


--
-- Name: mission_resource mission_resource_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_resource
    ADD CONSTRAINT mission_resource_pkey PRIMARY KEY (mission_id, resource_id);


--
-- Name: mission_subscription mission_subscription_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_subscription
    ADD CONSTRAINT mission_subscription_pkey UNIQUE (mission_id, client_uid, username);


--
-- Name: mission_uid_keyword mission_uid_keyword_id_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_uid_keyword
    ADD CONSTRAINT mission_uid_keyword_id_key UNIQUE (id);


--
-- Name: mission_uid_keyword mission_uid_keyword_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_uid_keyword
    ADD CONSTRAINT mission_uid_keyword_pkey PRIMARY KEY (id);


--
-- Name: mission_uid mission_uid_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_uid
    ADD CONSTRAINT mission_uid_pkey PRIMARY KEY (mission_id, uid);


--
-- Name: oauth_access_token oauth_access_token_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.oauth_access_token
    ADD CONSTRAINT oauth_access_token_pkey PRIMARY KEY (authentication_id);


--
-- Name: oauth_client_details oauth_client_details_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.oauth_client_details
    ADD CONSTRAINT oauth_client_details_pkey PRIMARY KEY (client_id);


--
-- Name: oauth_client_token oauth_client_token_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.oauth_client_token
    ADD CONSTRAINT oauth_client_token_pkey PRIMARY KEY (authentication_id);


--
-- Name: permission permission_id_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.permission
    ADD CONSTRAINT permission_id_key UNIQUE (id);


--
-- Name: permission permission_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.permission
    ADD CONSTRAINT permission_pkey PRIMARY KEY (id);


--
-- Name: properties_keys properties_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.properties_keys
    ADD CONSTRAINT properties_keys_pkey PRIMARY KEY (properties_uid_id, id);


--
-- Name: properties_keys properties_keys_unique; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.properties_keys
    ADD CONSTRAINT properties_keys_unique UNIQUE (id);


--
-- Name: properties_uid properties_uid_id; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.properties_uid
    ADD CONSTRAINT properties_uid_id PRIMARY KEY (id);


--
-- Name: properties_uid properties_uid_unique; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.properties_uid
    ADD CONSTRAINT properties_uid_unique UNIQUE (uid);


--
-- Name: properties_value properties_value_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.properties_value
    ADD CONSTRAINT properties_value_pkey PRIMARY KEY (properties_key_id, id);


--
-- Name: resource resource_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.resource
    ADD CONSTRAINT resource_pkey PRIMARY KEY (id);


--
-- Name: role role_id_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_id_key UNIQUE (id);


--
-- Name: role_permission role_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.role_permission
    ADD CONSTRAINT role_permission_pkey PRIMARY KEY (role_id, permission_id);


--
-- Name: role role_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_pkey PRIMARY KEY (id);


--
-- Name: schema_version schema_version_pk; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.schema_version
    ADD CONSTRAINT schema_version_pk PRIMARY KEY (installed_rank);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: tak_user tak_user_id_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.tak_user
    ADD CONSTRAINT tak_user_id_key UNIQUE (id);


--
-- Name: tak_user tak_user_id_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.tak_user
    ADD CONSTRAINT tak_user_id_pkey PRIMARY KEY (id);


--
-- Name: tak_user tak_user_user_name_key; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.tak_user
    ADD CONSTRAINT tak_user_user_name_key UNIQUE (user_name);


--
-- Name: mission_layer uid_unique; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_layer
    ADD CONSTRAINT uid_unique UNIQUE (uid);


--
-- Name: video_connections video_connection_pkey; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.video_connections
    ADD CONSTRAINT video_connection_pkey PRIMARY KEY (id);


--
-- Name: video_connections_v2 video_connection_pkey_v2; Type: CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.video_connections_v2
    ADD CONSTRAINT video_connection_pkey_v2 PRIMARY KEY (id);


--
-- Name: active_group_cache_username_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX active_group_cache_username_idx ON public.active_group_cache USING btree (username);


--
-- Name: certificate_idx1; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX certificate_idx1 ON public.certificate USING btree (subject_dn);


--
-- Name: certificate_idx2; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX certificate_idx2 ON public.certificate USING btree (hash);


--
-- Name: chat_cot_type_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX chat_cot_type_idx ON public.cot_router_chat USING btree (cot_type);


--
-- Name: chat_cot_type_servertime_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX chat_cot_type_servertime_idx ON public.cot_router_chat USING btree (cot_type, servertime);


--
-- Name: chat_dest_uid_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX chat_dest_uid_idx ON public.cot_router_chat USING btree (dest_uid);


--
-- Name: chat_dest_uid_servertime_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX chat_dest_uid_servertime_idx ON public.cot_router_chat USING btree (dest_uid, servertime);


--
-- Name: chat_event_pt_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX chat_event_pt_idx ON public.cot_router_chat USING gist (event_pt);


--
-- Name: chat_servertime_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX chat_servertime_idx ON public.cot_router_chat USING btree (servertime);


--
-- Name: chat_time_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX chat_time_idx ON public.cot_router_chat USING btree ("time");


--
-- Name: chat_uid_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX chat_uid_idx ON public.cot_router_chat USING btree (uid);


--
-- Name: chat_uid_servertime_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX chat_uid_servertime_idx ON public.cot_router_chat USING btree (uid, servertime);


--
-- Name: client_endpoint_event_created_ts_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX client_endpoint_event_created_ts_idx ON public.client_endpoint_event USING btree (created_ts);


--
-- Name: client_endpoint_event_idx1; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX client_endpoint_event_idx1 ON public.client_endpoint_event USING btree (client_endpoint_id);


--
-- Name: client_endpoint_event_idx2; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX client_endpoint_event_idx2 ON public.client_endpoint_event USING btree (client_endpoint_id, connection_event_type_id);


--
-- Name: client_endpoint_idx2; Type: INDEX; Schema: public; Owner: tak
--

CREATE UNIQUE INDEX client_endpoint_idx2 ON public.client_endpoint USING btree (callsign, uid, username);


--
-- Name: client_endpoint_uid_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX client_endpoint_uid_idx ON public.client_endpoint USING btree (uid);


--
-- Name: cot_type_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX cot_type_idx ON public.cot_router USING btree (cot_type);


--
-- Name: cot_type_servertime_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX cot_type_servertime_idx ON public.cot_router USING btree (cot_type, servertime);


--
-- Name: data_feed_cot_cot_router_id_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX data_feed_cot_cot_router_id_idx ON public.data_feed_cot USING btree (cot_router_id);


--
-- Name: data_feed_cot_data_feed_id_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX data_feed_cot_data_feed_id_idx ON public.data_feed_cot USING btree (data_feed_id);


--
-- Name: event_pt_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX event_pt_idx ON public.cot_router USING gist (event_pt);


--
-- Name: fed_event_details; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX fed_event_details ON public.fed_event USING gin (details);


--
-- Name: fed_event_time; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX fed_event_time ON public.fed_event USING btree (event_time);


--
-- Name: fki_device_profile_directory_fkey; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX fki_device_profile_directory_fkey ON public.device_profile_directory USING btree (device_profile_id);


--
-- Name: fki_device_profile_fkey; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX fki_device_profile_fkey ON public.device_profile_file USING btree (device_profile_id);


--
-- Name: groups_name_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX groups_name_idx ON public.groups USING btree (name);


--
-- Name: icon_uid_group_name_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX icon_uid_group_name_idx ON public.icon USING btree (iconsetuid, group_name, name);


--
-- Name: iconset_uid_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX iconset_uid_idx ON public.iconset USING btree (uid);


--
-- Name: maplayer_default_layer_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX maplayer_default_layer_idx ON public.maplayer USING btree (default_layer);


--
-- Name: maplayer_uid_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX maplayer_uid_idx ON public.maplayer USING btree (uid);


--
-- Name: mission_change_hash_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX mission_change_hash_idx ON public.mission_change USING btree (hash);


--
-- Name: mission_change_main_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX mission_change_main_idx ON public.mission_change USING btree (mission_name, ts DESC, change_type);


--
-- Name: mission_change_ts_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX mission_change_ts_idx ON public.mission_change USING btree (ts);


--
-- Name: mission_change_type_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX mission_change_type_idx ON public.mission_change USING btree (change_type);


--
-- Name: mission_change_uid_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX mission_change_uid_idx ON public.mission_change USING btree (uid);


--
-- Name: mission_guid; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX mission_guid ON public.mission USING btree (guid);


--
-- Name: mission_invitation_mission_id; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX mission_invitation_mission_id ON public.mission_invitation USING btree (mission_id);


--
-- Name: mission_log_mission_name_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX mission_log_mission_name_idx ON public.mission_log_mission_name USING btree (missionnames);


--
-- Name: mission_log_servertime_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX mission_log_servertime_idx ON public.mission_log USING btree (servertime);


--
-- Name: resource_creatoruid_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX resource_creatoruid_idx ON public.resource USING btree (creatoruid);


--
-- Name: resource_hash_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX resource_hash_idx ON public.resource USING btree (hash);


--
-- Name: resource_submissiontime; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX resource_submissiontime ON public.resource USING btree (submissiontime);


--
-- Name: schema_version_s_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX schema_version_s_idx ON public.schema_version USING btree (success);


--
-- Name: servertime_hour_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX servertime_hour_idx ON public.cot_router USING btree (servertime_hour);


--
-- Name: servertime_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX servertime_idx ON public.cot_router USING btree (servertime);


--
-- Name: servertime_no_bts_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX servertime_no_bts_idx ON public.cot_router USING btree (servertime) WHERE ((cot_type)::text <> 'b-t-f'::text);


--
-- Name: time_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX time_idx ON public.cot_router USING btree ("time");


--
-- Name: uid_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX uid_idx ON public.cot_router USING btree (uid);


--
-- Name: uid_servertime_idx; Type: INDEX; Schema: public; Owner: tak
--

CREATE INDEX uid_servertime_idx ON public.cot_router USING btree (uid, servertime);


--
-- Name: certificate_private_key certificate_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.certificate_private_key
    ADD CONSTRAINT certificate_fk FOREIGN KEY (certificate_id) REFERENCES public.certificate(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: classification_caveat classification_caveat_caveat_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.classification_caveat
    ADD CONSTRAINT classification_caveat_caveat_id_fk FOREIGN KEY (caveat_id) REFERENCES public.caveat(id);


--
-- Name: classification_caveat classification_caveat_clssification_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.classification_caveat
    ADD CONSTRAINT classification_caveat_clssification_id_fk FOREIGN KEY (classification_id) REFERENCES public.classification(id);


--
-- Name: client_endpoint_event client_endpoint_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.client_endpoint_event
    ADD CONSTRAINT client_endpoint_fk FOREIGN KEY (client_endpoint_id) REFERENCES public.client_endpoint(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: client_endpoint_event connection_event_type_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.client_endpoint_event
    ADD CONSTRAINT connection_event_type_fk FOREIGN KEY (connection_event_type_id) REFERENCES public.connection_event_type(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: cot_image cot_image_cot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_image
    ADD CONSTRAINT cot_image_cot_id_fkey FOREIGN KEY (cot_id) REFERENCES public.cot_router(id);


--
-- Name: cot_link cot_link_containing_event_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_link
    ADD CONSTRAINT cot_link_containing_event_fkey FOREIGN KEY (containing_event) REFERENCES public.cot_router(id);


--
-- Name: cot_thumbnail cot_thumbnail_cot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_thumbnail
    ADD CONSTRAINT cot_thumbnail_cot_id_fkey FOREIGN KEY (cot_id) REFERENCES public.cot_router(id);


--
-- Name: cot_thumbnail cot_thumbnail_cot_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.cot_thumbnail
    ADD CONSTRAINT cot_thumbnail_cot_image_id_fkey FOREIGN KEY (cot_image_id) REFERENCES public.cot_image(id);


--
-- Name: data_feed_filter_group data_feed_filter_group_data_feed_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.data_feed_filter_group
    ADD CONSTRAINT data_feed_filter_group_data_feed_id_fk FOREIGN KEY (data_feed_id) REFERENCES public.data_feed(id) ON DELETE CASCADE;


--
-- Name: data_feed_tag data_feed_tag_data_feed_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.data_feed_tag
    ADD CONSTRAINT data_feed_tag_data_feed_id_fk FOREIGN KEY (data_feed_id) REFERENCES public.data_feed(id) ON DELETE CASCADE;


--
-- Name: device_profile_directory device_profile_directory_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.device_profile_directory
    ADD CONSTRAINT device_profile_directory_fkey FOREIGN KEY (device_profile_id) REFERENCES public.device_profile(id);


--
-- Name: device_profile_file device_profile_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.device_profile_file
    ADD CONSTRAINT device_profile_fkey FOREIGN KEY (device_profile_id) REFERENCES public.device_profile(id);


--
-- Name: icon fk313c79784b3989; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.icon
    ADD CONSTRAINT fk313c79784b3989 FOREIGN KEY (iconset_id) REFERENCES public.iconset(id);


--
-- Name: mission_invitation invitation_role_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_invitation
    ADD CONSTRAINT invitation_role_id_fk FOREIGN KEY (role_id) REFERENCES public.role(id);


--
-- Name: mission mission_default_role_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission
    ADD CONSTRAINT mission_default_role_id_fk FOREIGN KEY (default_role_id) REFERENCES public.role(id);


--
-- Name: mission_keyword mission_keyword_mission_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_keyword
    ADD CONSTRAINT mission_keyword_mission_id_fk FOREIGN KEY (mission_id) REFERENCES public.mission(id);


--
-- Name: mission_resource_keyword mission_resource_keyword_mission_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_resource_keyword
    ADD CONSTRAINT mission_resource_keyword_mission_id_fk FOREIGN KEY (mission_id) REFERENCES public.mission(id);


--
-- Name: mission_resource mission_resource_mission_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_resource
    ADD CONSTRAINT mission_resource_mission_id_fk FOREIGN KEY (mission_id) REFERENCES public.mission(id);


--
-- Name: mission_uid_keyword mission_uid_keyword_mission_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_uid_keyword
    ADD CONSTRAINT mission_uid_keyword_mission_id_fk FOREIGN KEY (mission_id) REFERENCES public.mission(id);


--
-- Name: mission_uid mission_uid_mission_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_uid
    ADD CONSTRAINT mission_uid_mission_id_fk FOREIGN KEY (mission_id) REFERENCES public.mission(id);


--
-- Name: mission parent_mission_fkey; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission
    ADD CONSTRAINT parent_mission_fkey FOREIGN KEY (parent_mission_id) REFERENCES public.mission(id);


--
-- Name: properties_keys properties_keys_properties_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.properties_keys
    ADD CONSTRAINT properties_keys_properties_id_fk FOREIGN KEY (properties_uid_id) REFERENCES public.properties_uid(id) ON DELETE CASCADE;


--
-- Name: properties_value properties_value_key_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.properties_value
    ADD CONSTRAINT properties_value_key_id_fk FOREIGN KEY (properties_key_id) REFERENCES public.properties_keys(id) ON DELETE CASCADE;


--
-- Name: role_permission role_permission_permissions_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.role_permission
    ADD CONSTRAINT role_permission_permissions_id_fk FOREIGN KEY (permission_id) REFERENCES public.permission(id);


--
-- Name: role_permission role_permission_role_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.role_permission
    ADD CONSTRAINT role_permission_role_id_fk FOREIGN KEY (role_id) REFERENCES public.role(id);


--
-- Name: mission_subscription subscription_role_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: tak
--

ALTER TABLE ONLY public.mission_subscription
    ADD CONSTRAINT subscription_role_id_fk FOREIGN KEY (role_id) REFERENCES public.role(id);


--
-- Name: TABLE active_group_cache; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.active_group_cache TO tak;


--
-- Name: TABLE caveat; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.caveat TO tak;


--
-- Name: TABLE certificate; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.certificate TO tak;


--
-- Name: TABLE certificate_private_key; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.certificate_private_key TO tak;


--
-- Name: TABLE ci_trap; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.ci_trap TO tak;


--
-- Name: TABLE classification; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.classification TO tak;


--
-- Name: TABLE classification_caveat; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.classification_caveat TO tak;


--
-- Name: TABLE client_endpoint; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.client_endpoint TO tak;


--
-- Name: TABLE client_endpoint_event; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.client_endpoint_event TO tak;


--
-- Name: TABLE clientdetails; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.clientdetails TO tak;


--
-- Name: TABLE connection_event_type; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.connection_event_type TO tak;


--
-- Name: TABLE cot_image; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.cot_image TO tak;


--
-- Name: TABLE cot_link; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.cot_link TO tak;


--
-- Name: TABLE cot_router; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.cot_router TO tak;


--
-- Name: TABLE cot_router_chat; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.cot_router_chat TO tak;


--
-- Name: TABLE cot_thumbnail; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.cot_thumbnail TO tak;


--
-- Name: TABLE data_feed; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.data_feed TO tak;


--
-- Name: TABLE data_feed_cot; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.data_feed_cot TO tak;


--
-- Name: TABLE data_feed_filter_group; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.data_feed_filter_group TO tak;


--
-- Name: TABLE data_feed_tag; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.data_feed_tag TO tak;


--
-- Name: TABLE data_feed_type_pl; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.data_feed_type_pl TO tak;


--
-- Name: TABLE device_profile; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.device_profile TO tak;


--
-- Name: TABLE device_profile_directory; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.device_profile_directory TO tak;


--
-- Name: TABLE device_profile_file; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.device_profile_file TO tak;


--
-- Name: TABLE error_logs; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.error_logs TO tak;


--
-- Name: TABLE fed_event; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.fed_event TO tak;


--
-- Name: TABLE fed_event_kind_pl; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.fed_event_kind_pl TO tak;


--
-- Name: TABLE group_bitpos_sequence; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.group_bitpos_sequence TO tak;


--
-- Name: TABLE group_type_pl; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.group_type_pl TO tak;


--
-- Name: TABLE groups; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.groups TO tak;


--
-- Name: TABLE icon; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.icon TO tak;


--
-- Name: TABLE iconset; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.iconset TO tak;


--
-- Name: TABLE latestcot; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.latestcot TO tak;


--
-- Name: TABLE resource; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.resource TO tak;


--
-- Name: TABLE latestresource; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.latestresource TO tak;


--
-- Name: TABLE maplayer; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.maplayer TO tak;


--
-- Name: TABLE mission; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission TO tak;


--
-- Name: TABLE mission_change; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_change TO tak;


--
-- Name: TABLE mission_external_data; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_external_data TO tak;


--
-- Name: TABLE mission_feed; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_feed TO tak;


--
-- Name: TABLE mission_invitation; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_invitation TO tak;


--
-- Name: TABLE mission_keyword; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_keyword TO tak;


--
-- Name: TABLE mission_layer; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_layer TO tak;


--
-- Name: TABLE mission_log; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_log TO tak;


--
-- Name: TABLE mission_log_hash; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_log_hash TO tak;


--
-- Name: TABLE mission_log_keyword; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_log_keyword TO tak;


--
-- Name: TABLE mission_log_mission_name; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_log_mission_name TO tak;


--
-- Name: TABLE mission_resource; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_resource TO tak;


--
-- Name: TABLE mission_resource_keyword; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_resource_keyword TO tak;


--
-- Name: TABLE mission_subscription; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_subscription TO tak;


--
-- Name: TABLE mission_uid; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_uid TO tak;


--
-- Name: TABLE mission_uid_keyword; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.mission_uid_keyword TO tak;


--
-- Name: TABLE oauth_access_token; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.oauth_access_token TO tak;


--
-- Name: TABLE oauth_approvals; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.oauth_approvals TO tak;


--
-- Name: TABLE oauth_client_details; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.oauth_client_details TO tak;


--
-- Name: TABLE oauth_client_token; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.oauth_client_token TO tak;


--
-- Name: TABLE oauth_code; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.oauth_code TO tak;


--
-- Name: TABLE oauth_refresh_token; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.oauth_refresh_token TO tak;


--
-- Name: TABLE permission; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.permission TO tak;


--
-- Name: TABLE properties_keys; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.properties_keys TO tak;


--
-- Name: TABLE properties_uid; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.properties_uid TO tak;


--
-- Name: TABLE properties_value; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.properties_value TO tak;


--
-- Name: TABLE role; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.role TO tak;


--
-- Name: TABLE role_permission; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.role_permission TO tak;


--
-- Name: TABLE schema_version; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.schema_version TO tak;


--
-- Name: TABLE subscriptions; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.subscriptions TO tak;


--
-- Name: TABLE tak_user; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.tak_user TO tak;


--
-- Name: TABLE video_connections; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.video_connections TO tak;


--
-- Name: TABLE video_connections_v2; Type: ACL; Schema: public; Owner: tak
--

GRANT ALL ON TABLE public.video_connections_v2 TO tak;

--
-- PostgreSQL database dump complete
--
