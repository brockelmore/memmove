// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import "./Array.sol";

type DoublyLinkedList is bytes32;

// A basic wrapper around an array that returns a pointer to an element in
// the array. Unfortunately without generics, the user has to cast from a pointer to a type
// held in memory manually
//
// is indexable
//
// data structure:                 |-----------------------------------------------------------------|
//   |-----------------------------|                        x       |-------|                        |      x
//   |                             v                        |       |       v                        |      |
// [ptr, ptr2, ptr3, ptr4]         {value, other value, previous, next}     {value, other value, previous, next}
//        |                                                       ^
//        |-------------------------------------------------------|
//
// where `mload(add(ptr, linkingOffset))` (aka `next`) == ptr2

library IndexableDoublyLinkedListLib {
    using ArrayLib for Array;

    function newIndexableDoublyLinkedList(uint16 capacityHint) internal pure returns (DoublyLinkedList s) {
        s = DoublyLinkedList.wrap(Array.unwrap(ArrayLib.newArray(capacityHint)));
    }

    function capacity(DoublyLinkedList self) internal pure returns (uint256 cap) {
        cap = Array.wrap(DoublyLinkedList.unwrap(self)).capacity();
    }

    function length(DoublyLinkedList self) internal pure returns (uint256 len) {
        len = Array.wrap(DoublyLinkedList.unwrap(self)).length();
    }

    function push_no_link(DoublyLinkedList self, bytes32 element) internal view returns (DoublyLinkedList s) {
        s = DoublyLinkedList.wrap(
            Array.unwrap(
                Array.wrap(DoublyLinkedList.unwrap(self)).push(uint256(element))
            )
        );
    }

    // linkingOffset is the offset from the element ptr that is written to 
    function push_and_link(DoublyLinkedList self, bytes32 element, uint256 backwardLinkingOffset, uint256 forwardLinkingOffset) internal view returns (DoublyLinkedList s) {
        Array asArray = Array.wrap(DoublyLinkedList.unwrap(self));

        uint256 len = asArray.length();
        if (len == 0) {
            // nothing to link to
            Array arrayS = asArray.push(uint256(element), 3);
            s = DoublyLinkedList.wrap(Array.unwrap(arrayS));
        } else {
            // over alloc by 3
            Array arrayS = asArray.push(uint256(element), 3);
            uint256 newPtr = arrayS.unsafe_get(len);
            uint256 lastPtr = arrayS.unsafe_get(len - 1);
            
            // link the previous element with the new element
            assembly ("memory-safe") {
                mstore(add(newPtr, backwardLinkingOffset), lastPtr)
                mstore(add(lastPtr, forwardLinkingOffset), newPtr)
            }

            s = DoublyLinkedList.wrap(Array.unwrap(arrayS));
        }
    }

    function next(DoublyLinkedList /*self*/, bytes32 element, uint256 forwardLinkingOffset) internal pure returns (bool exists, bytes32 elem) {
        assembly ("memory-safe") {
            elem := mload(add(element, forwardLinkingOffset))
            exists := gt(elem, 0x00)
        }
    }

    function previous(DoublyLinkedList /*self*/, bytes32 element, uint256 backwardLinkingOffset) internal pure returns (bool exists, bytes32 elem) {
        assembly ("memory-safe") {
            elem := mload(add(element, backwardLinkingOffset))
            exists := gt(elem, 0x00)
        }
    }

    function get(DoublyLinkedList self, uint256 index) internal pure returns (bytes32 elementPointer) {
        elementPointer = bytes32(Array.wrap(DoublyLinkedList.unwrap(self)).get(index));
    }

    function unsafe_get(DoublyLinkedList self, uint256 index) internal pure returns (bytes32 elementPointer) {
        elementPointer = bytes32(Array.wrap(DoublyLinkedList.unwrap(self)).unsafe_get(index));
    }
}

// the only way to traverse is to start at head and iterate via `next`. More memory efficient, better for maps
//
// data structure:
//   |-------------------------tail---------------------------------|
//   |head|-------------------------------------------|     |-------|
//   |    v                                           |     |       v
//  head, dataStruct{.., next} }     dataStruct{.., prev, next}     dataStruct{.., next}
//                          |        ^
//                          |--------|
//
// `head` is a packed word split as 40, 40, 80, 80 of backward & forward linking offset, ptr to first element, ptr to last element
// `head` *isn't* stored in memory because it fits in a word 

library DoublyLinkedListLib {
    uint256 constant HEAD_MASK = 0xFFFFFFFFFFFFFFFFFFFF00000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 constant TAIL_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000000;

    function newDoublyLinkedList(uint40 _backwardLinkingOffset, uint40 _forwardLinkingOffset) internal pure returns (DoublyLinkedList s) {
        assembly ("memory-safe") {
            s := shl(176, or(shl(40, _backwardLinkingOffset), _forwardLinkingOffset))
        }
    }

    function tail(DoublyLinkedList s) internal pure returns (bytes32 elemPtr) {
        assembly ("memory-safe") {
            elemPtr := shr(176, shl(160, s))
        }
    }

    function head(DoublyLinkedList s) internal pure returns (bytes32 elemPtr) {
        assembly ("memory-safe") {
            elemPtr := shr(176, shl(80, s))
        }
    }

    function forwardLinkingOffset(DoublyLinkedList s) internal pure returns (uint80 offset) {
        assembly ("memory-safe") {
            offset := shr(216, shl(40, s))
        }
    }

    function backwardLinkingOffset(DoublyLinkedList s) internal pure returns (uint80 offset) {
        assembly ("memory-safe") {
            offset := shr(216, s)
        }
    }

    function set_head(DoublyLinkedList self, bytes32 element) internal pure returns (DoublyLinkedList s) {
        assembly ("memory-safe") {
            s := or(and(self, HEAD_MASK), shl(96, element))
        }
    }

    // manually links one element to another
    function set_link(DoublyLinkedList self, bytes32 prevElem, bytes32 nextElem) internal pure {
        assembly ("memory-safe") {
            // store the new element as the `next` ptr for the tail
            mstore(
                add(
                    prevElem,
                    shr(216, shl(40, self)) // add the offset size to get `next`
                ),
                nextElem
            )
            mstore(
                add(
                    nextElem,
                    shr(216, self) // add the offset size to get `next`
                ),
                prevElem
            )
        }
    }

    function push_and_link(DoublyLinkedList self, bytes32 element) internal pure returns (DoublyLinkedList s) {
        assembly ("memory-safe") {
            switch gt(shr(176, shl(80, self)), 0) 
            case 1 {
                let tailElement := shr(176, shl(160, self))
                // store the new element as the `next` ptr for the tail
                mstore(
                    add(
                        tailElement,
                        shr(216, shl(40, self)) // get forwardLinkingOffset 
                    ),
                    element
                )

                // link the old tail to the new tail
                mstore(
                    add(
                        element,
                        shr(216, self)
                    ),
                    tailElement
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

    function next(DoublyLinkedList self, bytes32 element) internal pure returns (bool exists, bytes32 elem) {
        assembly ("memory-safe") {
            elem := mload(add(element, shr(216, shl(40, self))))
            exists := gt(elem, 0x00)
        }
    }

    function previous(DoublyLinkedList self, bytes32 element) internal pure returns (bool exists, bytes32 elem) {
        assembly ("memory-safe") {
            elem := mload(add(element, shr(216, self)))
            exists := gt(elem, 0x00)
        }
    }
}