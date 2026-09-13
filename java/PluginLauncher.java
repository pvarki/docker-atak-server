package fi.pvarki.tak;

import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import org.apache.ignite.Ignite;
import org.springframework.boot.SpringApplication;
import com.bbn.marti.remote.util.LoggingConfigPropertiesSetupUtil;
import tak.server.ignite.IgniteConfigurationHolder;
import tak.server.ignite.IgniteHolder;
import tak.server.plugins.service.PluginService;
import tak.server.util.JavaVersionChecker;

/** Start the unmodified plugin service using the container's Ignite XML. */
public final class PluginLauncher {
    private PluginLauncher() {}

    public static void main(String[] args) throws Exception {
        JavaVersionChecker.check();
        IgniteConfigurationHolder holder = IgniteConfigurationHolder.getInstance();
        holder.setIgniteConfiguration(holder.getIgniteConfiguration(
                "takserver-plugin-manager-profile", holder.getTAKIgniteConfiguration()));
        Ignite ignite = IgniteHolder.getInstance().getIgnite();
        if (ignite == null) {
            throw new IllegalStateException("Plugin Ignite client did not start");
        }
        // PluginService exposes its Ignite bean through this private static field.
        // Its main() replaces the XML bind address with localhost, so initialize
        // the same bean here before starting its unchanged Spring application.
        Field field = PluginService.class.getDeclaredField("ignite");
        field.setAccessible(true);
        field.set(null, ignite);
        LoggingConfigPropertiesSetupUtil.getInstance().setupLoggingConfiguration();
        try {
            SpringApplication.run(PluginService.class, args);
            Files.writeString(Path.of(System.getenv("TAK_RUNTIME_DIR"), "ready"), "ready");
        } catch (Exception | Error failure) {
            ignite.close();
            throw failure;
        }
    }
}
