// List references to functions whose names contain one of the supplied terms.
// @category SimCity2000

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.symbol.Reference;

public class ListFunctionCallers extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length < 1) {
            throw new IllegalArgumentException(
                "Usage: ListFunctionCallers.java NAME_FRAGMENT ..."
            );
        }

        FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
        while (functions.hasNext() && !monitor.isCancelled()) {
            Function target = functions.next();
            String lowerName = target.getName().toLowerCase();
            boolean matched = false;
            for (String argument : arguments) {
                if (lowerName.contains(argument.toLowerCase())) {
                    matched = true;
                    break;
                }
            }
            if (!matched) {
                continue;
            }
            println(target.getEntryPoint() + "\t" + target.getName());
            for (Reference reference : getReferencesTo(target.getEntryPoint())) {
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
