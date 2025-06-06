// Export concise decompiler output for named addresses.
// @category SimCity2000

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

public class DecompileAddresses extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length < 2) {
            throw new IllegalArgumentException(
                "Usage: DecompileAddresses.java OUTPUT_DIR ADDRESS[=NAME] ..."
            );
        }

        Path outputDirectory = Paths.get(arguments[0]);
        Files.createDirectories(outputDirectory);

        DecompInterface decompiler = new DecompInterface();
        decompiler.openProgram(currentProgram);
        try {
            for (int index = 1; index < arguments.length; index++) {
                exportFunction(decompiler, outputDirectory, arguments[index]);
            }
        }
        finally {
            decompiler.dispose();
        }
    }

    private void exportFunction(
        DecompInterface decompiler, Path outputDirectory, String specification
    ) throws Exception {
        String[] parts = specification.split("=", 2);
        Address address = toAddr(parts[0]);
        String label = parts.length == 2 ? parts[1] : parts[0];
        label = label.replaceAll("[^A-Za-z0-9_.-]", "_");

        Function function = getFunctionContaining(address);
        if (function == null) {
            function = getFunctionAt(address);
        }
        if (function == null) {
            disassemble(address);
            function = createFunction(address, null);
        }
        if (function == null) {
            printerr("No function contains " + address);
            return;
        }

        DecompileResults result = decompiler.decompileFunction(function, 120, monitor);
        if (!result.decompileCompleted() || result.getDecompiledFunction() == null) {
            printerr("Decompiler failed for " + address + ": " + result.getErrorMessage());
            return;
        }

        String header = String.format(
            "/* program=%s requested=%s entry=%s ghidra_name=%s */%n%n",
            currentProgram.getName(),
            address,
            function.getEntryPoint(),
            function.getName()
        );
        Path outputPath = outputDirectory.resolve(label + ".c");
        Files.write(
            outputPath,
            (header + result.getDecompiledFunction().getC()).getBytes(StandardCharsets.UTF_8)
        );
        println("Wrote " + outputPath);
    }
}
