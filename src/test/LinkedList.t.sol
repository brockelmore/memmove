// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../LinkedList.sol";

struct U256 {
    uint256 value;
    uint256 next;
}

contract LinkedListTest is DSTest {
    using IndexableLinkedListLib for LinkedList;
    function setUp() public {}

    function testLinkedList() public {
        LinkedList pa = LinkedListLib.newLinkedList(5);
        U256 memory a = U256({value: 100, next: 0});
        pa = pa.push_no_link(pointer(a));
        for (uint256 i; i < 6; i++) {
            U256 memory b = U256({value: 101 + i, next: 0});
            pa = pa.push_and_link(pointer(b), 0x20);
        }

        for (uint256 i; i < 7; i++) {
            bytes32 ptr = pa.get(i);
            uint256 k;
            assembly {
                k := mload(ptr)
            }
            assertEq(k, 100 + i);
        }
    }

    function pointer(U256 memory a) internal returns(bytes32 ptr) {
        assembly {
            ptr := a
        }
    }
}