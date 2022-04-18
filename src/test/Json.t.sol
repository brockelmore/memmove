// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Json.sol";
import "../Array.sol";
import "./Vm.sol";

contract JsonTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);
    using JsonLib for Json;
    using ArrayLib for Array;
    function setUp() public {}

    function testJson() public {
        // {
        //     "test1":  [1, 2, 3, 4, 5],
        //     "test2":  [1, 2, 3, 4, 5],
        //     "property": "name"
        // }

        Json json = JsonLib.newJson(2);
        Array arr = ArrayLib.newArray(4);
        Array arr2 = ArrayLib.newArray(5);
        for (uint256 i; i < 5; i++) {
            arr.push(i);
        }

        for (uint256 i; i < 5; i++) {
            arr2.unsafe_push(i);
        }

        json.insert("test1", arr);
        json.insert("test2", arr2);

        string memory name = "name";
        json.insert("property",  name);
        // emit log_named_bytes32("name ptr", pointer(name));
        
        (, Array theArr) = json.getArray("test1");
        (, Array theArr2) = json.getArray("test2");
        (, string memory prop) = json.getString("property");

        emit log_named_bytes32("prop ptr", pointer(prop));
        assertEq(prop, "name");
        
        uint256 l1 = theArr.length();
        for (uint256 i;  i < l1; i++) {
            assertEq(theArr.unsafe_get(i), i);
        }

        uint256 l2 = theArr2.length();
        for (uint256 i;  i < l2; i++) {
            assertEq(theArr2.unsafe_get(i), i);
        }
    }

    function pointer(string memory a) internal pure returns(bytes32 ptr) {
        assembly {
            ptr := a
        }
    }

    function pointer(bytes memory a) internal pure returns(bytes32 ptr) {
        assembly {
            ptr := a
        }
    }
} 