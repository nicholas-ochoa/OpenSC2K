// Dump an address range from the loaded program to an external file.
// @category SimCity2000

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

public class DumpBytes extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length != 3) {
            throw new IllegalArgumentException(
                "Usage: DumpBytes.java OUTPUT_PATH ADDRESS LENGTH"
            );
        }

        Path outputPath = Paths.get(arguments[0]);
        Address address = toAddr(arguments[1]);
        int length = Integer.decode(arguments[2]);
        if (length < 1) {
            throw new IllegalArgumentException("Length must be positive");
        }

        byte[] data = new byte[length];
        int count = currentProgram.getMemory().getBytes(address, data);
        if (count != length) {
            throw new IllegalStateException(
                "Read " + count + " of " + length + " bytes at " + address
            );
        }
        Path parent = outputPath.getParent();
        if (parent != null) {
            Files.createDirectories(parent);
        }
        Files.write(outputPath, data);
        println("Wrote " + length + " bytes from " + address + " to " + outputPath);
    }
}
