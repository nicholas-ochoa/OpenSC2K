// Export references to named data or code addresses.
// @category SimCity2000

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class TraceReferences extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length < 2) {
            throw new IllegalArgumentException(
                "Usage: TraceReferences.java OUTPUT_FILE ADDRESS[=NAME] ..."
            );
        }

        List<String> lines = new ArrayList<>();
        lines.add("program\ttarget\tlabel\tfrom\tfunction_entry\tfunction_name\ttype");

        for (int index = 1; index < arguments.length; index++) {
            String[] parts = arguments[index].split("=", 2);
            Address target = toAddr(parts[0]);
            String label = parts.length == 2 ? parts[1] : parts[0];
            Reference[] references = getReferencesTo(target);
            if (references.length == 0) {
                lines.add(String.join("\t", currentProgram.getName(), target.toString(), label));
                continue;
            }

            for (Reference reference : references) {
                Address from = reference.getFromAddress();
                Function function = getFunctionContaining(from);
                lines.add(String.join(
                    "\t",
                    currentProgram.getName(),
                    target.toString(),
                    label,
                    from.toString(),
                    function == null ? "" : function.getEntryPoint().toString(),
                    function == null ? "" : function.getName(),
                    reference.getReferenceType().toString()
                ));
            }
        }

        Path outputPath = Paths.get(arguments[0]);
        if (outputPath.getParent() != null) {
            Files.createDirectories(outputPath.getParent());
        }
        Files.write(outputPath, lines, StandardCharsets.UTF_8);
        println("Wrote " + outputPath);
    }
}
