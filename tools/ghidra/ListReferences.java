// List code and data references to one or more addresses.
// @category SimCity2000

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;

public class ListReferences extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length < 1) {
            throw new IllegalArgumentException(
                "Usage: ListReferences.java ADDRESS ..."
            );
        }

        for (String argument : arguments) {
            Address target = toAddr(argument);
            println("References to " + target + ":");
            Reference[] references = getReferencesTo(target);
            for (Reference reference : references) {
                Address source = reference.getFromAddress();
                Function function = getFunctionContaining(source);
                String functionText = function == null
                    ? "<no function>"
                    : function.getName() + " at " + function.getEntryPoint();
                println(
                    "  " + source + " " + reference.getReferenceType()
                    + " " + functionText
                );
            }
        }
    }
}
