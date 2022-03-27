// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

// create a user defined type that is a pointer to memory
type Array is bytes32;

/* 
Memory layout:
offset..offset+32: current first unset element (cheaper to have it first most of the time), aka "length"
offset+32..offset+64: capacity of elements in array
offset+64..offset+64+(capacity*32): elements

nominclature:
 - capacity: total number of elements able to be stored prior to having to perform a move
 - length/current unset index: the number of defined items in the array

a dynamic array is such a primitive data structure that it should be extremely optimized. so everything is in assembly
*/
library ArrayLib {
    function newArray(uint16 capacityHint) internal pure returns (Array s) {
        assembly ("memory-safe") {
            // grab free mem ptr
            s := mload(0x40)
            
            // update free memory pointer based on array's layout:
            //  + 32 bytes for capacity
            //  + 32 bytes for current unset pointer/length
            //  + 32*capacity
            //  + current free memory pointer (s is equal to mload(0x40)) 
            mstore(0x40, add(s, mul(add(0x02, capacityHint), 0x20)))

            // store the capacity in the second word (see memory layout above)
            mstore(add(0x20, s), capacityHint)

            // store length as 0 because otherwise the compiler may have rugged us
            mstore(s, 0x00)
        }
    }

    // capacity of elements before a move would occur
    function capacity(Array self) internal pure returns (uint256 cap) {
        assembly ("memory-safe") {
            cap := mload(add(0x20, self))
        }
    }

    // number of set elements in the array
    function length(Array self) internal pure returns (uint256 len) {
        assembly ("memory-safe") {
            len := mload(self)
        }
    }

    // gets a ptr to an element
    function unsafe_ptrToElement(Array self, uint256 index) internal pure returns (bytes32 ptr) {
        assembly ("memory-safe") {
            ptr := add(self, mul(0x20, add(0x02, index)))
        }
    }

    // overloaded to default push function with 0 overallocation
    function push(Array self, uint256 elem) internal view returns (Array ret) {
        ret = push(self, elem, 0);
    }

    // push an element safely into the array - will perform a move if needed as well as updating the free memory pointer
    // returns the new pointer.
    //
    // WARNING: if a move occurs, the user *must* update their pointer, thus the returned updated pointer. safest
    // method is *always* updating the pointer
    function push(Array self, uint256 elem, uint256 overalloc) internal view returns (Array) {
        Array ret;
        assembly ("memory-safe") {
            // set the return ptr
            ret := self
            // check if length == capacity (meaning no more preallocated space)
            switch eq(mload(self), mload(add(0x20, self))) 
            case 1 {
                // optimization: check if the free memory pointer is equal to the end of the preallocated space
                // if it is, we can just natively extend the array because nothing has been allocated *after*
                // us. i.e.:
                // evm_memory = [00...free_mem_ptr...Array.length...Array.lastElement]
                // this check compares free_mem_ptr to Array.lastElement, if they are equal, we know there is nothing after
                //
                // optimization 2: length == capacity in this case (per above) so we can avoid an add to look at capacity
                // to calculate where the last element it
                switch eq(mload(0x40), add(self, mul(add(0x02, mload(self)), 0x20))) 
                case 1 {
                    // the free memory pointer hasn't moved, i.e. free_mem_ptr == Array.lastElement, just extend

                    // Add 1 to the Array.capacity
                    mstore(add(0x20, self), add(0x01, mload(add(0x20, self))))

                    // the free mem ptr is where we want to place the next element
                    mstore(mload(0x40), elem)

                    // move the free_mem_ptr by a word (32 bytes. 0x20 in hex)
                    mstore(0x40, add(0x20, mload(0x40)))

                    // update the length
                    mstore(self, add(0x01, mload(self)))
                }
                default {
                    // we couldn't do the above optimization, use the `identity` precompile to perform a memory move
                    
                    // move the array to the free mem ptr by using the identity precompile which just returns the values
                    let array_size := mul(add(0x02, mload(self)), 0x20)
                    pop(
                        staticcall(
                            gas(), // pass gas
                            0x04,  // call identity precompile address 
                            self,  // arg offset == pointer to self
                            array_size,  // arg size: capacity + 2 * word_size (we add 2 to capacity to account for capacity and length words)
                            mload(0x40), // set return buffer to free mem ptr
                            array_size   // identity just returns the bytes of the input so equal to argsize 
                        )
                    )
                    
                    // add the element to the end of the array
                    mstore(add(mload(0x40), array_size), elem)

                    // add to the capacity
                    mstore(
                        add(0x20, mload(0x40)), // free_mem_ptr + word == new capacity word
                        add(add(0x01, overalloc), mload(add(0x20, mload(0x40)))) // add one + overalloc to capacity
                    )

                    // add to length
                    mstore(mload(0x40), add(0x01, mload(mload(0x40))))

                    // set the return ptr to the new array
                    ret := mload(0x40)

                    // update free memory pointer
                    // we also over allocate if requested
                    mstore(0x40, add(add(array_size, add(0x20, mul(overalloc, 0x20))), mload(0x40)))
                }
            }
            default {
                // we have capacity for the new element, store it
                mstore(
                    // mem_loc := capacity_ptr + (capacity + 2) * 32
                    // we add 2 to capacity to acct for capacity and length words, then multiply by element size
                    add(self, mul(add(0x02, mload(self)), 0x20)), 
                    elem
                )

                // update length
                mstore(self, add(0x01, mload(self)))
            }
        }
        return ret;
    }

    // used when you *guarantee* that the array has the capacity available to be pushed to.
    // no need to update return pointer in this case
    //
    // NOTE: marked as memory safe, but potentially not memory safe if the safety contract is broken by the caller
    function unsafe_push(Array self, uint256 elem) internal pure {
        assembly ("memory-safe") {
            mstore(
                // mem_loc := capacity_ptr + (capacity + 2) * 32
                // we add 2 to capacity to acct for capacity and length words, then multiply by element size
                add(self, mul(add(0x02, mload(self)), 0x20)),
                elem
            )

            // update length
            mstore(self, add(0x01, mload(self)))
        }
    }

    // used when you *guarantee* that the index, i, is within the bounds of length
    // NOTE: marked as memory safe, but potentially not memory safe if the safety contract is broken by the caller
    function unsafe_set(Array self, uint256 i, uint256 value) internal pure {
        assembly ("memory-safe") {
            mstore(add(self, mul(0x20, add(0x02, i))), value)
        }
    }

    function set(Array self, uint256 i, uint256 value) internal pure {
        // if the index is greater than or equal to the capacity, revert
        assembly ("memory-safe") {
            if lt(mload(add(0x20, self)), i) {
                // emit compiler native Panic(uint256) style error
                mstore(0x00, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x32)
                revert(0, 0x24)
            }
            mstore(add(self, mul(0x20, add(0x02, i))), value)
        }
    }

    // used when you *guarantee* that the index, i, is within the bounds of length
    // NOTE: marked as memory safe, but potentially not memory safe if the safety contract is broken by the caller
    function unsafe_get(Array self, uint256 i) internal pure returns (uint256 s) {
        assembly ("memory-safe") {
            s := mload(add(self, mul(0x20, add(0x02, i))))
        }
    }

    // a safe `get` that checks capacity
    function get(Array self, uint256 i) internal pure returns (uint256 s) {
        // if the index is greater than or equal to the capacity, revert
        assembly ("memory-safe") {
            if lt(mload(add(0x20, self)), i) {
                // emit compiler native Panic(uint256) style error
                mstore(0x00, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x32)
                revert(0, 0x24)
            }
            s := mload(add(self, mul(0x20, add(0x02, i))))
        }
    } 
}

// A wrapper around the lower level array that does one layer of indirection so that the pointer
// the user has to hold never moves. Effectively a reference to the array. i.e. push doesn't return anything
// because it doesnt need to. Slightly less efficient, generally adds 1-3 memops per func
library RefArrayLib {
    using ArrayLib for Array;

    function newArray(uint16 capacityHint) internal pure returns (Array s) {
        Array referenced = ArrayLib.newArray(capacityHint);
        assembly ("memory-safe") {
            // grab free memory pointer for return value
            s := mload(0x40)
            // store referenced array in s
            mstore(mload(0x40), referenced)
            // update free mem ptr
            mstore(0x40, add(mload(0x40), 0x20))
        }
    }

    // capacity of elements before a move would occur
    function capacity(Array self) internal pure returns (uint256 cap) {
        assembly ("memory-safe") {
            cap := mload(add(0x20, mload(self)))
        }
    }

    // number of set elements in the array
    function length(Array self) internal pure returns (uint256 len) {
        assembly ("memory-safe") {
            len := mload(mload(self))
        }
    }

    // gets a ptr to an element
    function unsafe_ptrToElement(Array self, uint256 index) internal pure returns (bytes32 ptr) {
        assembly ("memory-safe") {
            ptr := add(mload(self), mul(0x20, add(0x02, index)))
        }
    }

    // overloaded to default push function with 0 overallocation
    function push(Array self, uint256 elem) internal view {
        push(self, elem, 0);
    }

    // dereferences the array
    function deref(Array self) internal pure returns (Array s) {
        assembly ("memory-safe") {
            s := mload(self)
        }
    }

    // push an element safely into the array - will perform a move if needed as well as updating the free memory pointer
    function push(Array self, uint256 elem, uint256 overalloc) internal view {
        Array newArr = deref(self).push(elem, overalloc);
        assembly ("memory-safe") {
            // we always just update the pointer because it is cheaper to do so than check whether
            // the array moved
            mstore(self, newArr)
        }
    }

    // used when you *guarantee* that the array has the capacity available to be pushed to.
    // no need to update return pointer in this case
    function unsafe_push(Array self, uint256 elem) internal pure {
        // no need to update pointer
        deref(self).unsafe_push(elem);
    }

    // used when you *guarantee* that the index, i, is within the bounds of length
    // NOTE: marked as memory safe, but potentially not memory safe if the safety contract is broken by the caller
    function unsafe_set(Array self, uint256 i, uint256 value) internal pure {
        deref(self).unsafe_set(i, value);
    }

    function set(Array self, uint256 i, uint256 value) internal pure {
        deref(self).set(i, value);
    }

    // used when you *guarantee* that the index, i, is within the bounds of length
    // NOTE: marked as memory safe, but potentially not memory safe if the safety contract is broken by the caller
    function unsafe_get(Array self, uint256 i) internal pure returns (uint256 s) {
        s = deref(self).unsafe_get(i);
    }

    // a safe `get` that checks capacity
    function get(Array self, uint256 i) internal pure returns (uint256 s) {
        s = deref(self).get(i);
    }
}