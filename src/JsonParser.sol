pragma solidity >=0.8.13 <0.9.0;

type JsonParser is bytes32;
type Tokens is bytes32;

library JsonParserLib {
    // using ArrayLib for Tokens;

    // function position(JsonParser self) internal pure returns (uint256 offset) {
    //     offset := shr(176, s)
    // }

    // function increment(JsonParser self) internal pure returns (uint256 offset) {
    //     offset := shl(176, 0x01)
    // }

	// function parse(bytes memory str) internal pure returns (JsonParser s) {
 //        assembly ("memory-safe") {
 //            function parseObject(s, i) -> result, i {
 //                for {} iszero(eq(shr(248, mload(add(add(str, 0x20), i))), '}')) { i := add(i, 0x01)} {
 //                    let key := 0x00
 //                    key, i := parseString(s, i)
 //                }
 //            }

 //            function parseString(s, i) -> result, i {
 //                for {} iszero(eq(shr(248, mload(add(add(str, 0x20), i))), '}')) { i := add(i, 0x01)} {

 //                }
 //            }

 //            function parseJson(s, i) -> result {
 //                switch char(s, i)
 //                case '{' {
 //                    result := parseObject(s, i)
 //                }
 //                case '[' {

 //                }
 //                case '"' {

 //                }
 //                case 'n' {

 //                }
 //                case 't' {

 //                }
 //                case 'f' {

 //                }
 //                default {

 //                }
 //            }

 //            function char(s, i) -> result {
 //                result := shr(248, mload(add(add(s, 0x20), i)))
 //            }

 //            function parseNumber(s, i) -> result, i {
 //                let neg := eq(char(s, i), '-')
 //                i := add(0x01, i)
                
 //            }
 //        }
 //    }

    // function parseObject()
}