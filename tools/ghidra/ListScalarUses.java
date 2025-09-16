// List instruction operands that use one or more scalar values.
// @category SimCity2000

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.scalar.Scalar;

import java.util.HashSet;
import java.util.Set;

public class ListScalarUses extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length < 1) {
            throw new IllegalArgumentException(
                "Usage: ListScalarUses.java VALUE ..."
            );
        }

        Set<Long> values = new HashSet<>();
        for (String argument : arguments) {
            values.add(Long.decode(argument));
        }

        InstructionIterator instructions = currentProgram.getListing().getInstructions(true);
        while (instructions.hasNext() && !monitor.isCancelled()) {
            Instruction instruction = instructions.next();
            boolean matched = false;
            for (int operand = 0; operand < instruction.getNumOperands(); operand++) {
                for (Object object : instruction.getOpObjects(operand)) {
                    if (object instanceof Scalar) {
                        Scalar scalar = (Scalar)object;
                        if (
                            values.contains(scalar.getUnsignedValue())
                            || values.contains(scalar.getSignedValue())
                        ) {
                            matched = true;
                        }
                    }
                }
            }
            if (!matched) {
                continue;
            }
            Address address = instruction.getAddress();
            Function function = getFunctionContaining(address);
            println(
                address + "\t"
                + (function == null ? "" : function.getEntryPoint()) + "\t"
                + (function == null ? "" : function.getName()) + "\t"
                + instruction
            );
        }
    }
}
