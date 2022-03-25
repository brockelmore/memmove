// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import "./Array.sol";
import "./LinkedList.sol";

// create a user defined type that is a pointer to memory
type Mapping is bytes32;

struct Entry {
	bytes32 key;
	bytes32 value;
	bytes32 next;
}

// A mapping with the following structure:
// |------------|                      |------------|        |------------|
// |            |                      | key        |   |--> | key        |   |-> ...      
// |  bucket 1  | - holds pointer to > | value      |   |    | value      |   |     
// |            |                      | ptr_to ----|---|    | ptr_to ----|---|
// |------------|                      |------------|        |------------|
// |            |
// |  bucket 2  | ...
// |            |
// |------------|
// |     ...    |
// where the number of buckets is determined by the capacity. The number of buckets is
// currently static at initialization, but this limitation could be lifted later
// 
// in general, its a memory/lookup speed tradeoff. We use a basic modulo operation for bucketing,
// which isn't ideal
//
// Complexity: best case O(1), worst case O(n)
library MappingLib {
	using ArrayLib for Array;
	using LinkedListLib for LinkedList;

	function newMapping(uint8 capacityHint) internal pure returns (Mapping s) {
		// memory pointers will never be > 2**128, as that would be 340282366920938463463374607431768211456 bytes of memory
		// which is impossible in the EVM
		Array bucketArray = ArrayLib.newArray(capacityHint);
		for (uint256 i; i < capacityHint; i++) {
			// create a new linked list with a link offset of 64 bytes
			uint256 linkedListPtr = uint256(LinkedList.unwrap(LinkedListLib.newLinkedList(0x40)));
			bucketArray.unsafe_push(linkedListPtr);
		}

        s = Mapping.wrap(Array.unwrap(bucketArray));
    }

    function buckets(Mapping self) internal pure returns (uint256 buckets) {
    	buckets = Array.wrap(Mapping.unwrap(self)).capacity();
    }

    // since we never resize the buckets array, the mapping itself can never move out from under us
	function insert(Mapping self, bytes32 key, uint256 value) internal view {
		uint256 bucket = uint256(key) % buckets(self);

		Entry memory entry = Entry({
			key: key,
			value: bytes32(value),
			next: bytes32(0)
		});
		bytes32 entryPtr;

		assembly ("memory-safe") {
			entryPtr := entry
		}

		// Safety:
		//  1. since buckets is guaranteed to be the capacity, we are able to make this unsafe_get
		LinkedList linkedList = LinkedList.wrap(bytes32(Array.wrap(Mapping.unwrap(self)).unsafe_get(bucket)));
		Array.wrap(Mapping.unwrap(self)).unsafe_set(bucket, uint256(LinkedList.unwrap(linkedList.push_and_link(entryPtr))));
	}

	function set(Mapping self, bytes32 key, uint256 value) internal view {
		insert(self, key, value);
	}

	function get(Mapping self, bytes32 key) internal pure returns (bool found, uint256 val) {
		uint256 bucket = uint256(key) % buckets(self);
		LinkedList linkedList = LinkedList.wrap(bytes32(Array.wrap(Mapping.unwrap(self)).unsafe_get(bucket)));
		bytes32 element = linkedList.head();
		bool success = true;
		while (success) {
			assembly ("memory-safe") {
				let elemKey := mload(element)
				if eq(elemKey, key) {
					val   := mload(add(element, 0x20))
					found := 1
				}
			}
			if (found) {
				break;
			}
			(success, element) = linkedList.next(element);
		}
	}
}