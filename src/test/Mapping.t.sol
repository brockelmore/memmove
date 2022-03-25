// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Mapping.sol";
import "forge-std/Vm.sol";

contract MappingTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);
    using MappingLib for Mapping;
    function setUp() public {}

    function createTempMap(uint8 num) internal returns (Mapping map) {
        map = MappingLib.newMapping(num);
        uint256 g0 = gasleft();
        for (uint256  i; i < num; i++) {
            map.insert(bytes32(i), i);
        }
        uint256 g1 = gasleft();
        emit log_named_uint("insert cost per", (g0 - g1) / num);
    }

    function getTempMap(Mapping map, uint8 num) internal {
        uint256 g0 = gasleft();
        for (uint256  i; i < num; i++) {
            (bool exists, uint256 val) = map.get(bytes32(i));
            // emit log_named_uint("index", i);
            // emit log_named_uint("value", val);
            assertTrue(exists);
            assertEq(val, i);
        }
        uint256 g1 = gasleft();
        emit log_named_uint("get cost per", (g0 - g1) / num);
    }

    function testMap() public {
        Mapping map = createTempMap(50);
        Mapping map2 = createTempMap(10);
        getTempMap(map, 50);
        getTempMap(map2, 10);
    }

    function testMapInstantiationCost() public {
        uint256 g0 = gasleft();
        MappingLib.newMapping(1);
        uint256 g1 = gasleft();
        emit log_named_uint("cost per instantiation: 1", (g0 - g1));
    }
    
    function testMapInstantiationCost5() public {
        uint256 g0 = gasleft();
        MappingLib.newMapping(5);
        uint256 g1 = gasleft();
        emit log_named_uint("cost per instantiation: 5", (g0 - g1) / 5);
    }
    
    function testMapInstantiationCost10() public {
        uint256 g0 = gasleft();
        MappingLib.newMapping(10);
        uint256 g1 = gasleft();
        emit log_named_uint("cost per instantiation: 10", (g0 - g1) / 10);
    }
    
    function testMapInstantiationCost50() public {
        uint256 g0 = gasleft();
        MappingLib.newMapping(50);
        uint256 g1 = gasleft();
        emit log_named_uint("cost per instantiation: 50", (g0 - g1) / 50);
    }

    function testMapInstantiationCost100() public {
        uint256 g0 = gasleft();
        MappingLib.newMapping(100);
        uint256 g1 = gasleft();
        emit log_named_uint("cost per instantiation: 100", (g0 - g1) / 100);
    }

    function testFuzzBrutalizeMemoryMap(bytes memory randomBytes, uint16 num) public {
        vm.assume(num < 5000);
        // brutalizes the memory and explicity does not update the free memory pointer 
        assembly ("memory-safe") {
            pop(
                staticcall(
                    gas(), // pass gas
                    0x04,  // call identity precompile address 
                    randomBytes,  // arg offset == pointer to self
                    mload(randomBytes),  // arg size: length of random bytes
                    mload(0x40), // set return buffer to free mem ptr
                    mload(randomBytes)   // identity just returns the bytes of the input so equal to argsize 
                )
            )
        }

        Mapping map = createTempMap(50);
        getTempMap(map, 50);
    }
} 