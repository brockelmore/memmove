// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Mapping.sol";
import "./Vm.sol";
import "./Array.t.sol";

contract MappingTest is DSTest, MemoryBrutalizer {
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

    function testMapCheckedInsertUpdate() public {
        Mapping map = MappingLib.newMapping(1);
        map.insert("test1", 1);
        uint256 g0 = gasleft();
        map.insert("test1", 2);
        uint256 g1 = gasleft();
        (, uint256 val) = map.get("test1");
        emit log_named_uint("get", val);
        emit log_named_uint("cost per checked insert short path", (g0 - g1));
    }

    function testMapCheckedInsert() public {
        Mapping map = MappingLib.newMapping(1);
        uint256 g0 = gasleft();
        map.insert("test1", 2);
        uint256 g1 = gasleft();
        (, uint256 val) = map.get("test1");
        emit log_named_uint("get", val);
        emit log_named_uint("cost per checked insert short path", (g0 - g1));
    }

    function testMapUncheckedInsert() public {
        Mapping map = MappingLib.newMapping(1);
        uint256 g0 = gasleft();
        map.insert("test1", 2);
        uint256 g1 = gasleft();
        (, uint256 val) = map.get("test1");
        emit log_named_uint("get", val);
        emit log_named_uint("cost per unchecked insert", (g0 - g1));
    }

    function testMapUpdate() public {
        Mapping map = MappingLib.newMapping(1);
        map.insert("test1", 1);
        uint256 g0 = gasleft();
        map.update("test1", 2);
        uint256 g1 = gasleft();
        (, uint256 val) = map.get("test1");
        emit log_named_uint("get", val);
        emit log_named_uint("cost per update", (g0 - g1));
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

    function testFuzzBrutalizeMemoryMap(bytes memory randomBytes, uint16 num) public brutalizeMemory(randomBytes) {
        vm.assume(num < 5000);
        Mapping map = createTempMap(50);
        getTempMap(map, 50);
    }
} 