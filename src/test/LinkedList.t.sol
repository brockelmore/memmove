// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../LinkedList.sol";
import "./Array.t.sol";
import "./Vm.sol";

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

    function testIndexableLinkedList() public {
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

    function pointer(U256 memory a) internal pure returns(bytes32 ptr) {
        assembly {
            ptr := a
        }
    }
}

contract LinkedListTest is DSTest, MemoryBrutalizer {
    Vm vm = Vm(HEVM_ADDRESS);

    using LinkedListLib for LinkedList;
    function setUp() public {}

    function testFuzzBrutalizeMemoryLL(bytes memory randomBytes, uint16 num) public brutalizeMemory(randomBytes) {
        vm.assume(num < 5000);
        vm.assume(num > 0);
        LinkedList pa = LinkedListLib.newLinkedList(0x20);
        uint256 lnum = uint256(num);
        uint256 init = 1337;
        for (uint256 i;  i < lnum; i++) {
            U256 memory b = U256({value: init + i, next: 0});
            pa = pa.push_and_link(pointer(b));
        }

        bytes32 element = pa.head();
        bool success = true;
        uint256 ctr = 0;
        while (success) {
            // convert the ptr to our struct type
            U256 memory elem = fromPointer(element);
            // check it is what we expected
            assertEq(elem.value, 1337 + ctr);
            ++ctr;
            // walk to the next element
            (success, element) = pa.next(element);
        }
        assertEq(ctr, num);
    }

    function testLinkedList() public {
        LinkedList pa = LinkedListLib.newLinkedList(0x20);
        for (uint256 i; i < 7; i++) {
            U256 memory b = U256({value: 100 + i, next: 0});
            pa = pa.push_and_link(pointer(b));
        }

        bytes32 element = pa.head();
        bool success = true;
        uint256 ctr = 0;
        while (success) {
            // convert the ptr to our struct type
            U256 memory elem = fromPointer(element);
            // check it is what we expected
            assertEq(elem.value, 100 + ctr);
            ++ctr;
            // walk to the next element
            (success, element) = pa.next(element);
        }
        assertEq(ctr, 7);
    }

    function testLinkedListGas() public {
        LinkedList pa = LinkedListLib.newLinkedList(0x20);
        for (uint256 i; i < 2; i++) {
            U256 memory b = U256({value: 100 + i, next: 0});
            pa = pa.push_and_link(pointer(b));
        }

        uint256 g0 = gasleft();
        bytes32 element = pa.head();
        uint256 g1 = gasleft();
        (, element) = pa.next(element);
        uint256 g2 = gasleft();
        emit log_named_uint("get head gas", g0 - g1);
        emit log_named_uint("get next gas", g1 - g2);
    }


    function pointer(U256 memory a) internal pure returns (bytes32 ptr) {
        assembly {
            ptr := a
        }
    }

    function fromPointer(bytes32 ptr) internal pure returns (U256 memory a) {
        assembly ("memory-safe") {
            a := ptr
        }
    }
}