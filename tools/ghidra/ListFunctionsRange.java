// List functions whose entry points are in one address range.
// @category SimCity2000

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;

public class ListFunctionsRange extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length != 2) {
            throw new IllegalArgumentException(
                "Usage: ListFunctionsRange.java START_ADDRESS END_ADDRESS"
            );
        }
        Address start = toAddr(arguments[0]);
        Address end = toAddr(arguments[1]);
        FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(start, true);
        for (Function function : functions) {
            Address entry = function.getEntryPoint();
            if (entry.compareTo(end) > 0) {
                break;
            }
            println(String.format(
                "%s\t%s\t%s",
                entry,
                function.getBody().getMaxAddress(),
                function.getName()
            ));
        }
    }
}
