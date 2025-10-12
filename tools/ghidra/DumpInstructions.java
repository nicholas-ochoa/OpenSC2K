// Dump decoded instructions from a loaded program to an external text file.
// @category SimCity2000

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

public class DumpInstructions extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length != 3) {
            throw new IllegalArgumentException(
                "Usage: DumpInstructions.java OUTPUT_PATH ADDRESS LENGTH"
            );
        }

        Path outputPath = Paths.get(arguments[0]);
        Address start = toAddr(arguments[1]);
        long length = Long.decode(arguments[2]);
        if (length < 1) {
            throw new IllegalArgumentException("Length must be positive");
        }
        Address end = start.add(length - 1);
        StringBuilder output = new StringBuilder();
        InstructionIterator instructions = currentProgram.getListing().getInstructions(
            start, true
        );
        while (instructions.hasNext()) {
            Instruction instruction = instructions.next();
            if (instruction.getAddress().compareTo(end) > 0) {
                break;
            }
            output.append(instruction.getAddress())
                .append("  ")
                .append(instruction)
                .append(System.lineSeparator());
        }

        Path parent = outputPath.getParent();
        if (parent != null) {
            Files.createDirectories(parent);
        }
        Files.write(outputPath, output.toString().getBytes(StandardCharsets.UTF_8));
        println("Wrote instructions from " + start + " through " + end + " to " + outputPath);
    }
}
