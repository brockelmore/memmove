// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import "./Array.sol";

type LinkedList is bytes32;

// A basic wrapper around an array that returns a pointer to an element in
// the array. Unfortunately without generics, the user has to cast from a pointer to a type
// held in memory manually
//
// is indexable
//
// data structure:
//   |-----------------------------|                      |-------|
//   |                             v                      |       v  
// [ptr, ptr2, ptr3, ptr4]         {value, other value, next}     {value, other value, next}
//        |                                                       ^
//        |-------------------------------------------------------|
//
// where `mload(add(ptr, linkingOffset))` (aka `next`) == ptr2

library IndexableLinkedListLib {
    using ArrayLib for Array;

    function newIndexableLinkedList(uint16 capacityHint) internal pure returns (LinkedList s) {
        s = LinkedList.wrap(Array.unwrap(ArrayLib.newArray(capacityHint)));
    }

    function capacity(LinkedList self) internal pure returns (uint256 cap) {
        cap = Array.wrap(LinkedList.unwrap(self)).capacity();
    }

    function length(LinkedList self) internal pure returns (uint256 len) {
        len = Array.wrap(LinkedList.unwrap(self)).length();
    }

    function push_no_link(LinkedList self, bytes32 element) internal view returns (LinkedList s) {
        s = LinkedList.wrap(
            Array.unwrap(
                Array.wrap(LinkedList.unwrap(self)).push(uint256(element))
            )
        );
    }

    // linkingOffset is the offset from the element ptr that is written to 
    function push_and_link(LinkedList self, bytes32 element, uint256 linkingOffset) internal view returns (LinkedList s) {
        Array asArray = Array.wrap(LinkedList.unwrap(self));

        uint256 len = asArray.length();
        if (len == 0) {
            // nothing to link to
            Array arrayS = asArray.push(uint256(element), 3);
            s = LinkedList.wrap(Array.unwrap(arrayS));
        } else {
            // over alloc by 3
            Array arrayS = asArray.push(uint256(element), 3);
            uint256 newPtr = arrayS.unsafe_get(len);
            uint256 lastPtr = arrayS.unsafe_get(len - 1);
            
            // link the previous element with the new element
            assembly ("memory-safe") {
                mstore(add(lastPtr, linkingOffset), newPtr)
            }

            s = LinkedList.wrap(Array.unwrap(arrayS));
        }
    }

    function next(LinkedList /*self*/, bytes32 element, uint256 linkingOffset) internal pure returns (bool exists, bytes32 elem) {
        assembly ("memory-safe") {
            elem := mload(add(element, linkingOffset))
            exists := gt(elem, 0x00)
        }
    }

    function get(LinkedList self, uint256 index) internal pure returns (bytes32 elementPointer) {
        elementPointer = bytes32(Array.wrap(LinkedList.unwrap(self)).get(index));
    }

    function unsafe_get(LinkedList self, uint256 index) internal pure returns (bytes32 elementPointer) {
        elementPointer = bytes32(Array.wrap(LinkedList.unwrap(self)).unsafe_get(index));
    }
}

// the only way to traverse is to start at head and iterate via `next`. More memory efficient, better for maps
//
// data structure:
//   |-------------------------tail----------------------------|
//   |head|                                           |--------|
//   |    v                                           |        v
//  head, dataStruct{.., next} }     dataStruct{.., next}     dataStruct{.., next}
//                          |          ^
//                          |----------|
//
// `head` is a packed word split as 80, 80, 80 of linking offset, ptr to first element, ptr to last element
// `head` *isn't* stored in memory because it fits in a word 

library LinkedListLib {
    uint256 constant HEAD_MASK = 0xFFFFFFFFFFFFFFFFFFFF00000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 constant TAIL_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000000;

    function newLinkedList(uint80 _linkingOffset) internal pure returns (LinkedList s) {
        assembly ("memory-safe") {
            s := shl(176, _linkingOffset)
        }
    }

    function tail(LinkedList s) internal pure returns (bytes32 elemPtr) {
        assembly ("memory-safe") {
            elemPtr := shr(176, shl(160, s))
        }
    }

    function head(LinkedList s) internal pure returns (bytes32 elemPtr) {
        assembly ("memory-safe") {
            elemPtr := shr(176, shl(80, s))
        }
    }

    function linkingOffset(LinkedList s) internal pure returns (uint80 offset) {
        assembly ("memory-safe") {
            offset := shr(176, s)
        }
    }

    function set_head(LinkedList self, bytes32 element) internal pure returns (LinkedList s) {
        assembly ("memory-safe") {
            s := or(and(self, HEAD_MASK), shl(96, element))
        }
    }

    // manually links one element to another
    function set_link(LinkedList self, bytes32 prevElem, bytes32 nextElem) internal pure {
        assembly ("memory-safe") {
            // store the new element as the `next` ptr for the tail
            mstore(
                add(
                    prevElem, // get the tail ptr
                    shr(176, self) // add the offset size to get `next`
                ),
                nextElem
            )
        }
    }

    function push_and_link(LinkedList self, bytes32 element) internal pure returns (LinkedList s) {
        assembly ("memory-safe") {
            switch gt(shr(176, shl(80, self)), 0) 
            case 1 {
                // store the new element as the `next` ptr for the tail
                mstore(
                    add(
                        shr(176, shl(160, self)), // get the tail ptr
                        shr(176, self) // add the offset size to get `next`
                    ),
                    element
                )

                // update the tail ptr
                s := or(and(self, TAIL_MASK), shl(16, element))
            }
            default {
                // no head, set element as head and tail
                s := or(or(self, shl(96, element)), shl(16, element))
            }
        }
    }

    function next(LinkedList self, bytes32 element) internal pure returns (bool exists, bytes32 elem) {
        assembly ("memory-safe") {
            elem := mload(add(element, shr(176, self)))
            exists := gt(elem, 0x00)
        }
    }
}