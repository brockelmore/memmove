// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Array.sol";
import "./Vm.sol";

library stdError {
    bytes public constant indexOOBError = abi.encodeWithSignature("Panic(uint256)", 0x32);
}

abstract contract MemoryBrutalizer {
    // brutalizes memory with "temporary" values - good for testing
    // memory safety in fuzz tests. Explicitly doesn't update
    // the free memory pointer to simulate compiler generate
    // temporary values
    modifier brutalizeMemory(bytes memory brutalizeWith) {
        assembly ("memory-safe") {
            pop(
                staticcall(
                    gas(), // pass gas
                    0x04,  // call identity precompile address 
                    brutalizeWith,  // arg offset == pointer to self
                    mload(brutalizeWith),  // arg size: length of random bytes
                    mload(0x40), // set return buffer to free mem ptr
                    mload(brutalizeWith)   // identity just returns the bytes of the input so equal to argsize 
                )
            )
        }

        _;
    }
}

contract ArrayTest is DSTest, MemoryBrutalizer {
    Vm vm = Vm(HEVM_ADDRESS);

    using ArrayLib for Array;
    function setUp() public {}


    function testArray() public {
        Array pa = ArrayLib.newArray(5);
        // safe pushes
        pa.unsafe_push(125);
        pa.unsafe_push(126);
        pa.unsafe_push(127);
        pa.unsafe_push(128);
        pa.unsafe_push(129);
        pa = pa.push(130);
        pa = pa.push(131);
        pa = pa.push(132);
        pa = pa.push(133);
        pa = pa.push(134);
        pa = pa.push(135);
        for (uint256 i; i < 11; i++) {
            assertEq(pa.get(i), 125 + i);
        }
    }

    function testZeroArray() public {
        Array pa = ArrayLib.newArray(0);
        // safe pushes
        pa = pa.push(125);
        pa = pa.push(126);
        pa = pa.push(127);
        pa = pa.push(128);
        pa = pa.push(129);
        pa = pa.push(130);
        pa = pa.push(131);
        pa = pa.push(132);
        pa = pa.push(133);
        pa = pa.push(134);
        pa = pa.push(135);
        for (uint256 i; i < 11; i++) {
            assertEq(pa.get(i), 125 + i);
        }
    }

    function testBuiltInPanic() public {
        Array pa = ArrayLib.newArray(0);
        vm.expectRevert(stdError.indexOOBError);
        pa.set(1, 0);
    }

    function testFuzzBrutalizeMemory(bytes memory randomBytes, uint16 num) public brutalizeMemory(randomBytes) {
        vm.assume(num < 5000);

        Array pa = ArrayLib.newArray(num);
        uint256 lnum = uint256(num);
        uint256 init = 1337;
        for (uint256 i;  i < lnum; i++) {
            pa.unsafe_push(init + i);
        }

        init = init + num;
        for (uint256 i;  i < lnum; i++) {
            pa = pa.push(init + i);
        }

        init = 1337;
        for (uint256 i;  i < lnum*2; i++) {
            assertEq(pa.unsafe_get(i), init + i);
        }
    }

    function testMemoryInterruption() public {
        Array pa = ArrayLib.newArray(5);
        // safe pushes
        pa.unsafe_push(125);
        pa.unsafe_push(126);
        pa.unsafe_push(127);
        pa.unsafe_push(128);
        pa.unsafe_push(129);

        ArrayLib.newArray(5);

        pa = pa.push(130);
        pa = pa.push(131);
        pa = pa.push(132);
        pa = pa.push(133);
        pa = pa.push(134);
        pa = pa.push(135);
        for (uint256 i; i < 11; i++) {
            assertEq(pa.get(i), 125 + i);
        }
    }

    // unsafe pushes are cheaper than standard assigns
    function testUnsafeGasEfficiency() public {
        Array pa = ArrayLib.newArray(1);
        uint256 g0 = gasleft();
        pa.unsafe_push(125);
        uint256 g1 = gasleft();
        uint256[] memory a = new uint256[](1);
        a[0] = 125;
        uint256 g2 = gasleft();
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g1 - g2);
        emit log_named_uint("delta", (g1 - g2) - (g0 - g1));
    }

    function testUnsafeSetGasEfficiency() public {
        uint256[] memory a = new uint256[](1);
        Array pa = ArrayLib.newArray(1);
        uint256 g0 = gasleft();
        pa.unsafe_set(0, 125);
        uint256 g1 = gasleft();
        a[0] = 125;
        uint256 g2 = gasleft();
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g1 - g2);
    }

    function testSafeSetGasEfficiency() public {
        uint256[] memory a = new uint256[](1);
        Array pa = ArrayLib.newArray(1);
        uint256 g0 = gasleft();
        pa.set(0,  125);
        uint256 g1 = gasleft();
        a[0] = 125;
        uint256 g2 = gasleft();
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g1 - g2);
    }

    function testLength() public {
        Array pa = ArrayLib.newArray(1);
        uint256[] memory a = new uint256[](1);
        pa.unsafe_push(125);
        uint256 g0 = gasleft();
        pa.length();
        uint256 g1 = gasleft();
        a.length;
        uint256 g2 = gasleft();
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g1 - g2);
    }

    function testUnsafeGasEfficiencyGet() public {
        Array pa = ArrayLib.newArray(1);
        pa.unsafe_push(125);
        uint256 g0 = gasleft();
        pa.unsafe_get(0);
        uint256 g1 = gasleft();
        
        uint256[] memory a = new uint256[](1);
        a[0] = 125;
        uint256 g2 = gasleft();
        a[0];
        uint256 g3 = gasleft();
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g2 - g3);
    }

    function testCreationGas() public {
        uint256 g0 = gasleft();
        ArrayLib.newArray(5);
        uint256 g1 = gasleft();
        uint256[] memory a = new uint256[](5);
        uint256 g2 = gasleft();
        a[0] = 1;
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g1 - g2);
    }

    function testSafeGasEfficiencyGet() public {
        Array pa = ArrayLib.newArray(1);
        pa.unsafe_push(125);
        uint256 g0 = gasleft();
        pa.get(0);
        uint256 g1 = gasleft();
        
        uint256[] memory a = new uint256[](1);
        a[0] = 125;
        uint256 g2 = gasleft();
        a[0];
        uint256 g3 = gasleft();
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g2 - g3);
    }

    function testSafeGasEfficiency() public {
        Array pa = ArrayLib.newArray(1);
        uint256 g0 = gasleft();
        pa = pa.push(125);
        uint256 g1 = gasleft();
        uint256[] memory a = new uint256[](1);
        a[0] = 125;
        uint256 g2 = gasleft();
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g1 - g2);
    }
}

contract RefArrayTest is DSTest {
    using RefArrayLib for Array;
    function setUp() public {}

    function testArray() public {
        Array pa = RefArrayLib.newArray(5);
        // safe pushes
        pa.unsafe_push(125);
        pa.unsafe_push(126);
        pa.unsafe_push(127);
        pa.unsafe_push(128);
        pa.unsafe_push(129);
        pa.push(130);
        pa.push(131);
        pa.push(132);
        pa.push(133);
        pa.push(134);
        pa.push(135);
        for (uint256 i; i < 11; i++) {
            assertEq(pa.get(i), 125 + i);
        }
    }

    function testMemoryInterruption() public {
        Array pa = RefArrayLib.newArray(5);
        // safe pushes
        pa.unsafe_push(125);
        pa.unsafe_push(126);
        pa.unsafe_push(127);
        pa.unsafe_push(128);
        pa.unsafe_push(129);

        RefArrayLib.newArray(5);

        pa.push(130);
        pa.push(131);
        pa.push(132);
        pa.push(133);
        pa.push(134);
        pa.push(135);
        for (uint256 i; i < 11; i++) {
            assertEq(pa.get(i), 125 + i);
        }
    }

    // unsafe pushes are cheaper than standard assigns
    function testUnsafeGasEfficiency() public {
        uint256 g0 = gasleft();
        Array pa = RefArrayLib.newArray(1);
        pa.unsafe_push(125);
        uint256 g1 = gasleft();
        uint256[] memory a = new uint256[](1);
        a[0] = 125;
        uint256 g2 = gasleft();
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g1 - g2);
    }

    function testUnsafeGasEfficiencyGet() public {
        Array pa = RefArrayLib.newArray(1);
        pa.unsafe_push(125);
        uint256 g0 = gasleft();
        pa.unsafe_get(0);
        uint256 g1 = gasleft();
        
        uint256[] memory a = new uint256[](1);
        a[0] = 125;
        uint256 g2 = gasleft();
        a[0];
        uint256 g3 = gasleft();
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g2 - g3);
    }

    function testSafeGasEfficiencyGet() public {
        Array pa = RefArrayLib.newArray(1);
        pa.unsafe_push(125);
        uint256 g0 = gasleft();
        pa.get(0);
        uint256 g1 = gasleft();
        
        uint256[] memory a = new uint256[](1);
        a[0] = 125;
        uint256 g2 = gasleft();
        a[0];
        uint256 g3 = gasleft();
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g2 - g3);
    }

    function testSafeGasEfficiency() public {
        uint256 g0 = gasleft();
        Array pa = RefArrayLib.newArray(1);
        pa.push(125);
        uint256 g1 = gasleft();
        uint256[] memory a = new uint256[](1);
        a[0] = 125;
        uint256 g2 = gasleft();
        emit log_named_uint("Array gas", g0 - g1);
        emit log_named_uint("builtin gas", g1 - g2);
    }
}