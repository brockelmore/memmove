// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Mapping.sol";

contract MappingTest is DSTest {
    using MappingLib for Mapping;
    function setUp() public {}

    mapping(uint256 => uint256) internal tempStorage;


    function tempStore(uint8 num, uint8 reads) internal {
        for (uint256  i; i < num; i++) {
            tempStorage[i] = i;
        }
        for (uint j; j < reads; j++) {
            for (uint256  i; i < num; i++) {
                uint256 a = tempStorage[i];
            }
        }
        for (uint256  i; i < num; i++) {
            delete tempStorage[i];
        }
    }


    function tempMap(uint8 num) internal {
        Mapping map = MappingLib.newMapping(num);
        for (uint256  i; i < num; i++) {
            map.insert(bytes32(i), i);
        }
        for (uint256  i; i < num; i++) {
            map.get(bytes32(i));
        }
    }

    function testTempGas() public {
        tempStore(15, 30);
    }

    function testMapGas() public {
        tempMap(15);
    }

    function testMap() public {
        Mapping map = MappingLib.newMapping(1);
        uint256 g0 = gasleft();
        map.insert("test", 100);
        // map.get("test");
        uint256 g1 = gasleft();
        map.insert("test2", 101);
        uint256 g2 = gasleft();
        map.insert("test3", 102);
        uint256 g3 = gasleft();
        map.insert("test4", 103);
        uint256 g4 = gasleft();
        map.insert("test5", 104);
        uint256 g5 = gasleft();
        emit log_named_uint("first insert", g0 - g1);
        emit log_named_uint("2nd insert", g1 - g2);
        emit log_named_uint("3rd insert", g2 - g3);
        emit log_named_uint("4th insert", g3 - g4);
        emit log_named_uint("5th insert", g4 - g5);
        emit log_named_uint("all inserts gas", g0 - g5);
        uint256 g6 = gasleft();
        ( ,uint256 val) = map.get("test");
        uint256 g7 = gasleft();
        emit log_named_uint("first get", g6 - g7);
        emit log_named_uint("mapping value 1", val);
        uint256 g8 = gasleft();
        (,val) = map.get("test2");
        uint256 g9 = gasleft();
        emit log_named_uint("2nd get", g8 - g9);
        emit log_named_uint("mapping value 2", val);
        uint256 g10 = gasleft();
        (,val) = map.get("test3");
        uint256 g11 = gasleft();
        emit log_named_uint("3rd get", g10 - g11);
        emit log_named_uint("mapping value 3", val);
        (,val) = map.get("test4");
        emit log_named_uint("mapping value 4", val);
        (,val) = map.get("test5");
        emit log_named_uint("mapping value 5", val);
    }

    // function testMapGas() public {
    //     Mapping map = MappingLib.newMapping(5);
    //     uint256 g0 = gasleft();
    //     map.insert("test", 100);
    //     map.insert("test2", 100);
    //     map.insert("test3", 100);
    //     map.insert("test4", 100);
    //     map.insert("test5", 100);
    //     uint256 val = map.get("test");
    //     val = map.get("test2");
    //     val = map.get("test3");
    //     val = map.get("test4");
    //     val = map.get("test5");
    //     uint256 g1 = gasleft();
    //     emit log_named_uint("5 read/write", g0 - g1);
    // }
} 