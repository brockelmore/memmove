# memmove: A data structures library that does memory management for you

## Features

1. Dynamically sized in-memory [arrays](src/Array.sol#L19)
1. UX improved arrays via [references](src/Array.sol#L210)
1. Dynamically sized in-memory [linked lists](src/LinkedList.sol#L99)
1. Dynamically sized in-memory [indexable linked lists](src/LinkedList.sol#L21)
1. Dynamically sized in-memory [mappings](src/Mapping.sol#L36)
1. Dynamically sized in-memory [doubly linked lists](src/DoublyLinkedList.sol#L107)
1. Dynamically sized in-memory [indexable doubly linked lists](src/DoublyLinkedList.sol#L23)

Soon:
1. Dynamically sized in-memory [Json](src/Json.sol#L30)
1. String deserialization into Json

## Warning
This software is in *alpha*. There are likely bugs. Testing is relatively limited right now. Use at your own risk

## Gas costs

Below are some comparisons of Array vs a built in solidity array (`uint256[]`). Where possible a 1:1 comparison
is made. Otherwise, it is up to the reader to say what is most applicable to compare.
| op        | Array | Solidity builtin  |
|-----------|-------|-------------------|
|new(5)     |  75   |        147        |
|push       |  229  |        N/A        |
|unsafe_push|  78   |        N/A        |
|set        |  113  |        75         |
|unsafe_set |  29   |        N/A        |
|get        |  123  |        70         |
|unsafe_get |  48   |        N/A        |
|length     |  33   |        10         |



## Example Usage
### Array
```solidity
import "memmove/Array.sol";

contract ArrayUser {
    using ArrayLib for Array;

    function instantiateArray() public {
        // create the array
        //
        // note: the `5` here is what is called a `capacityHint`
        // basically is just an optimization for when you *know*
        // the size of your array or can decently guess.
        // You can make it 0, and it will work just fine
        Array pa = ArrayLib.newArray(5);

        // we can use unsafe_push because we know 5 elements
        // can for sure fit
        //
        // additionally, unsafe_pushes cannot move the array so
        // we dont have to do `pa = pa.unsafe_push(..)`
        //
        // this is actually cheaper than builtin solidity arrays!
        pa.unsafe_push(125);
        pa.unsafe_push(126);
        pa.unsafe_push(127);
        pa.unsafe_push(128);
        pa.unsafe_push(129);

        // after 5 elements, we have to use push, and update `pa`
        // we have to update pa because it may be moved when we
        // push
        //
        // for a better ux (but slightly less gas efficient), use `RefArrayLib`
        pa = pa.push(130);
        pa = pa.push(131);
        pa = pa.push(132);
        pa = pa.push(133);
        pa = pa.push(134);
        pa = pa.push(135);

        for (uint256 i; i < 11; i++) {
            require(pa.get(i) == 125 + i);
        }

        // performance hack!
        // we can read the length once, and then use
        // `unsafe_get` for indexing into the array
        //
        // this is also cheaper than builtin solidity array indexing!
        uint256 length = pa.length();
        for (uint256 i; i < length; i++) {
            require(pa.unsafe_get(i) == 125 + i);
        }
    }
}
```

### RefArray
```solidity
import "memmove/Array.sol";

contract RefArrayUser {
    // note using RefArrayLib instead of ArrayLib;
    // it has almost the same interface (just dont have to update the pointer) but
    // is slightly less gas efficient
    using RefArrayLib for Array;

    function instantiateRefArray() public {
        Array pa = RefArrayLib.newArray(5);

        // we can use unsafe_push because we know 5 elements
        // can for sure fit
        pa.unsafe_push(125);
        pa.unsafe_push(126);
        pa.unsafe_push(127);
        pa.unsafe_push(128);
        pa.unsafe_push(129);

        // we dont have to update the `pa` because even if the underlying array
        // is moved, we basically are holding a reference of the reference to the array
        //
        // when the reference to the array is updated, this library updates our reference for us
        pa.push(130);
        pa.push(131);
        pa.push(132);
        pa.push(133);
        pa.push(134);
        pa.push(135);

        for (uint256 i; i < 11; i++) {
            require(pa.get(i) == 125 + i);
        }
    }
}
```

### IndexableLinkedList
```solidity
import "memmove/LinkedList.sol";

struct U256 {
    uint256 value;
    uint256 next;
}

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

contract ILLUser {
    using IndexableLinkedListLib for LinkedList;

    function instantiateIndexableLinkedList() public {
        // create a new indexable linked list with a `capacityHint`
        // see below how we actually insert 7 elements, not just 5
        LinkedList pa = IndexableLinkedListLib.newIndexableLinkedList(5);

        // we create a struct in memory. the struct must be designed for the
        // linked list for now but this requirement may be lifted later
        //
        // `next` will be filled by the library, but you need to tell the library
        // where in the struct to find the pointer
        //
        // for this example, `nextParameterOffset` is 32, meaning 32 bytes. this is because from
        // the start of our struct, to the `next` parameter there is
        // one field before it, so 1*32bytes = 32bytes (32 bytes is the default length in memory)
        uint256 nextParameterOffset = 32;

        for (uint256 i; i < 7; i++) {
            // we create our linked list element in memory
            U256 memory b = U256({value: 100 + i, next: 0});

            // we push into the linked list, and if there is a preceeding value,
            // we will link this to that one
            //
            // otherwise, its the first element and will start the linked list
            //
            // note: we have to turn our struct into a bytes32 pointer.
            // for a struct you define, all you have to do is replace the `U256`
            // in the `pointer` function with the name of your struct
            pa = pa.push_and_link(pointer(b), nextParameterOffset);
        }

        // and we can index into the list and get the resulting values
        for (uint256 i; i < 7; i++) {
            bytes32 ptr = pa.get(i);
            U256 memory k = fromPointer(ptr);
            require(k.value == 100 + i);
        }
    }

    function pointer(U256 memory a) internal returns(bytes32 ptr) {
        assembly ("memory-safe") {
            ptr := a
        }
    }

    function fromPointer(bytes32 ptr) internal returns(U256 memory a) {
        assembly ("memory-safe") {
            a := ptr
        }
    }
}
```


### LinkedList
```solidity
import "memmove/LinkedList.sol";

struct U256 {
    uint256 value;
    uint256 next;
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

contract LLUser {
    // note: this uses `LinkedListLib` *not* `IndexableLinkedListLib`
    using LinkedListLib for LinkedList;

    function instantiateLinkedList() public {
        // unlike indexable linked list, we instantiate a normal linked
        // list with just the `nextParameterOffset`
        //
        // non-indexable linked lists (lls) live on the stack, with elements
        // being allocated nonsequentially in memory
        //
        // what `pa` is in this scenario is, is a packed type that consists of:
        // packedLoc0 - uint80: linkingOffset (the `nextParameterOffset` variable)
        // packedLoc1 - uint80: head ptr, a pointer to the head of the ll
        // packedLoc2 - uint80: tail ptr, a pointer to the tail of the ll
        //
        // note: there is an extra 16 bits that are unused, but you shouldn't rely
        // on being able to store anything in there as they are likely to get wiped out
        //
        // what this means is you can only access the head or the tail of a linked list
        // this have gas efficiencies associated with it, as well as being able to keep it
        // on the stack
        //
        // additionally, we never have to move the underlying data, it can stay wherever
        // because each element in our list holds a ptr to it
        uint256 nextParameterOffset = 32;
        LinkedList pa = LinkedListLib.newLinkedList(nextParameterOffset);

        for (uint256 i; i < 7; i++) {
            // we create our linked list element in memory
            U256 memory b = U256({value: 100 + i, next: 0});

            // we push into the linked list, and if there is a preceeding value,
            // we will link this to that one
            //
            // otherwise, its the first element and will start the linked list
            //
            // note: we have to turn our struct into a bytes32 pointer.
            // for a struct you define, all you have to do is replace the `U256`
            // in the `pointer` function with the name of your struct
            //
            // REMEMBER: you *must* update the `pa` value, otherwise you will lose your tail.
            pa = pa.push_and_link(pointer(b), nextParameterOffset);
        }

        // we *cannot* index into the linked list but we can walk it from head to tail:
        //
        // get the head  ptr
        bytes32 element = pa.head();
        bool success = true;

        // while we still have elements to walk:
        uint256 ctr = 0;
        while (success) {
            // convert the ptr to our struct type
            U256 memory elem = fromPointer(element);
            // check it is what we expected
            require(elem.value == 100 + ctr);
            ++ctr;
            // walk to the next element
            (success, element) = linkedList.next(element);
        }
        require(ctr == 7);
    }

    function pointer(U256 memory a) internal returns(bytes32 ptr) {
        assembly ("memory-safe") {
            ptr := a
        }
    }

    function fromPointer(bytes32 ptr) internal returns(U256 memory a) {
        assembly ("memory-safe") {
            a := ptr
        }
    }
}
```

### Mapping
```solidity
import "memmove/LinkedList.sol";

// A mapping with the following structure:
//                                      |---------------------------------------------------|
// |------------|                       |  |------------|        |------------|             |
// |            |                       |  | key        |   |--> | key        |   |-> ...   |
// |  bucket 1  | - holds pointer to >  |  | value      |   |    | value      |   |         |
// |            |                       |  | ptr_to ----|---|    | ptr_to ----|---|         |
// |------------|                       |  |------------|        |------------|             |
// |            |                       |---------------------------------------------------|
// |  bucket 2  | ...
// |            |
// |------------|
// |     ...    |
// |------------|
// where the number of buckets is determined by the capacity. The number of buckets is
// currently static at initialization, but this limitation could be lifted later
//
// in general, its a memory/lookup speed tradeoff. We use a basic modulo operation for bucketing,
// which isn't ideal
//
// Complexity: best case O(1), worst case O(n)

contract MappingUser {
    using MappingLib for Mapping;

    function createDynamicMap() internal returns (Mapping map) {
        // create a mapping with 5 buckets
        Mapping map = MappingLib.newMapping(5);

        // insert 7 items, where the key is a bytes32, and the value is a uint256
        // if your type doesnt match those, you can cast them into it. eventually will be
        // overloaded for you
        //
        // by default there cannot be duplicate keys. if you `insert` with the same key,
        // it will overwrite a previous value
        for (uint256  i; i < 7; i++) {
            map.insert(bytes32(i), i);
        }

        // we can get values by key
        for (uint256  i; i < 7; i++) {
            (bool keyExists, uint256 previouslyInsertedValue) = map.get(bytes32(i));
            require(keyExists);
            require(previouslyInsertedValue == i);
        }

        // we can insert values in an unchecked manner. this is slightly more gas efficient
        // but may lead you to unnecessarily expanding one of the linked lists that
        // are used under the hood, making subsequent gets for values
        // added after a faulty unchecked insert cost more
        //
        // additionally faulty unchecked inserts *wont* update the value for the key
        for (uint256  i; i < 7; i++) {
            // note we in theory are updating all the values here, but in the subsequent
            // `get` calls, the old value will return
            map.uncheckedInsert(bytes32(i), i + 1);
        }

        for (uint256  i; i < 7; i++) {
            (bool keyExists, uint256 previouslyInsertedValue) = map.get(bytes32(i));
            require(keyExists);
            // despite our `uncheckedInsert` for exiting keys, we end up with the old value
            require(previouslyInsertedValue == i);
        }

        // you can also check if a key exists in the set
        //
        // but in general this should only be used if you never actually want the value
        // because its the same time complexity as a normal `get` just strips returning the value
        bool keyExists = map.containsKey(bytes(1));
    }
}
```

### Json
TODO :)