// List defined strings and their references when their text contains a term.
// @category SimCity2000

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.data.StringDataInstance;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import ghidra.program.util.DefinedStringIterator;

public class ListStringReferences extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length < 1) {
            throw new IllegalArgumentException(
                "Usage: ListStringReferences.java TEXT_FRAGMENT ..."
            );
        }

        for (Data data : DefinedStringIterator.forProgram(currentProgram, currentSelection)) {
            if (monitor.isCancelled()) {
                break;
            }
            StringDataInstance instance = StringDataInstance.getStringDataInstance(data);
            String value = instance.getStringValue();
            if (value == null) {
                continue;
            }
            String lowerValue = value.toLowerCase();
            boolean matched = false;
            for (String argument : arguments) {
                if (lowerValue.contains(argument.toLowerCase())) {
                    matched = true;
                    break;
                }
            }
            if (!matched) {
                continue;
            }
            Address target = data.getAddress();
            println(target + "\t" + value.replace("\n", "\\n").replace("\r", "\\r"));
            for (Reference reference : getReferencesTo(target)) {
                Address source = reference.getFromAddress();
                Function caller = getFunctionContaining(source);
                println(
                    "  " + source + "\t" + reference.getReferenceType() + "\t"
                    + (caller == null
                        ? "<no function>"
                        : caller.getEntryPoint() + " " + caller.getName())
                );
            }
        }
    }
}
