// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../LinkedList.sol";
import "./Array.t.sol";
import "forge-std/Vm.sol";

struct U256 {
    uint256 value;
    uint256 next;
}

contract IndexableLinkedListTest is DSTest, MemoryBrutalizer {
    Vm vm = Vm(HEVM_ADDRESS);

    using IndexableLinkedListLib for LinkedList;
    function setUp() public {}

    function testFuzzBrutalizeMemoryILL(bytes memory randomBytes, uint16 num) public brutalizeMemory(randomBytes) {
        vm.assume(num < 5000);
        LinkedList pa = IndexableLinkedListLib.newIndexableLinkedList(num);
        uint256 lnum = uint256(num);
        uint256 init = 1337;
        for (uint256 i;  i < lnum; i++) {
            U256 memory b = U256({value: init + i, next: 0});
            pa = pa.push_and_link(pointer(b), 0x20);
        }

        for (uint256 i; i < lnum; i++) {
            // emit log_named_uint("i get", i);
            // emit log_named_uint("i get expected", init + i);
            bytes32 ptr = pa.get(i);
            uint256 k;
            assembly {
                k := mload(ptr)
            }
            assertEq(k, init+i);
        }
    }

    function testLinkedList() public {
        LinkedList pa = IndexableLinkedListLib.newIndexableLinkedList(5);
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