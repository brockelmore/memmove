// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import "./Array.sol";
import "./LinkedList.sol";
import "./Mapping.sol";

// create a user defined type that is a pointer to memory
type Json is bytes32;


enum JsonType {
    STRING,
    NUMBER,
    OBJECT,
    ARRAY,
    BOOL,
    NULL,
    ANY
}

struct JsonEntry {
    bytes32 key;
    bytes32 value;
    bytes32 next;
    JsonType encodingType;
}

// a not-to-spec json parser + data structure.
library JsonLib {
    using ArrayLib for Array;
    using LinkedListLib for LinkedList;
    using MappingLib for Mapping;

    error MismatchType();

    function newJson(uint16 capacityHint) internal pure returns (Json s) {
        Mapping map = MappingLib.newMapping(capacityHint);
        s = Json.wrap(Mapping.unwrap(map));
    }

    function insert(Json self, bytes32 key, uint256 value, JsonType encodingType) internal view {
        uint256 bucket = uint256(key) % buckets(self);

        JsonEntry memory entry = JsonEntry({
            key: key,
            value: bytes32(value),
            next: bytes32(0),
            encodingType: encodingType
        });
        bytes32 entryPtr;

        assembly ("memory-safe") {
            entryPtr := entry
        }

        // Safety:
        //  1. since buckets is guaranteed to be the capacity, we are able to make this unsafe_get
        LinkedList linkedList = LinkedList.wrap(bytes32(Array.wrap(Json.unwrap(self)).unsafe_get(bucket)));
        Array.wrap(Json.unwrap(self)).unsafe_set(bucket, uint256(LinkedList.unwrap(linkedList.push_and_link(entryPtr))));
    }

    function buckets(Json self) internal pure returns (uint256 buckets) {
        buckets = Array.wrap(Json.unwrap(self)).capacity();
    }

    function get(Json self, bytes32 key, JsonType expectedType) internal pure returns (bool found, uint256 val) {
        uint256 bucket = uint256(key) % buckets(self);
        LinkedList linkedList = LinkedList.wrap(bytes32(Array.wrap(Json.unwrap(self)).unsafe_get(bucket)));
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
                if (expectedType != JsonType.ANY) {
                    JsonType encodedType;
                    assembly ("memory-safe") {
                        encodedType := mload(add(element, 0x60))
                    }
                    
                    if (encodedType != expectedType) revert MismatchType();
                }

                break;
            }
            (success, element) = linkedList.next(element);
        }
    }

    function checkType(Json self, bytes32 key) internal pure returns (bool found, JsonType t) {
        uint256 bucket = uint256(key) % buckets(self);
        LinkedList linkedList = LinkedList.wrap(bytes32(Array.wrap(Json.unwrap(self)).unsafe_get(bucket)));
        bytes32 element = linkedList.head();
        bool success = true;
        while (success) {
            assembly ("memory-safe") {
                let elemKey := mload(element)
                if eq(elemKey, key) {
                    t   := mload(add(element, 0x60))
                    found := 1
                }
            }
            if (found) {
                break;
            }
            (success, element) = linkedList.next(element);
        }
    }

    function getString(Json self, bytes32 key) internal pure returns (bool found, string memory str) {
        (bool exists, uint256 str_ptr) = get(self, key, JsonType.STRING);
        assembly ("memory-safe") {
            found := exists
            str := str_ptr
        }
    }

    function getNumber(Json self, bytes32 key) internal pure returns (bool found, uint256 val) {
        (found, val) = get(self, key, JsonType.NUMBER);
    }

    function getObject(Json self, bytes32 key) internal pure returns (bool found, Json obj) {
        (bool exists, uint256 obj_ptr) = get(self, key, JsonType.OBJECT);
        assembly ("memory-safe") {
            found := exists
            obj := obj_ptr
        }
    }

    function objectAsMap(Json self) internal pure returns (Mapping map) {
        assembly ("memory-safe") {
            map := self
        }
    }

    function getArray(Json self, bytes32 key) internal pure returns (bool found, Array arr) {
        (bool exists, uint256 arr_ptr) = get(self, key, JsonType.ARRAY);
        assembly ("memory-safe") {
            found := exists
            arr := arr_ptr
        }
    }

    function getBool(Json self, bytes32 key) internal pure returns (bool found, bool val) {
        (bool exists, uint256 boo) = get(self, key, JsonType.BOOL);
        assembly ("memory-safe") {
            found := exists
            val := boo
        }
    }

    // Dont perform encoding type checks, just pass back the pointer/value
    function getAny(Json self, bytes32 key) internal pure returns (bool found, uint256 val) {
        (found, val) = get(self, key, JsonType.ANY);
    }

    function fromStr(Json self, string memory json_str) internal pure returns (Json s) {
        // TODO: parse the json into an instantiated json type (improves performance because we have a capacity hint at json creation)
        s = self;
    }
}