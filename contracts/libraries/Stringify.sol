// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

/**
 * @title library for string parsing to and from
 * @author priviprotocol
 */
library Stringify {
    /**
     * @dev converts a uint256 to string
     * @param i_ the uint256 to convert
     * @return uintAsString the string representation of the input
     */
    function toString(uint256 i_) internal pure returns (string memory uintAsString) {
        // match 0 case
        if (i_ == 0) {
            return "0";
        }

        uint256 len;
        uint256 j = i_;

        // count the uint256 input length
        while (j != 0) {
            len++;
            j /= 10;
        }

        // creates a byte string of size length of i_
        bytes memory bstr = new bytes(len);

        uint256 k = len;

        while (i_ != 0) {
            k = k - 1;

            // get the ASCII representation of the current last digit
            uint8 temp = (48 + uint8(i_ - (i_ / 10) * 10));

            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;

            i_ /= 10;
        }

        return string(bstr);
    }

    /**
     * @dev converts an address to string
     * @param x_ the address to convert
     * @return addressAsString the string representation of the input
     */
    function toString(address x_) internal pure returns (string memory addressAsString) {
        bytes memory s = new bytes(40);

        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x_)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }

        return string(s);
    }

    /**
     * @dev converts a byte to char (byte representation)
     * @param b_ the byte to convert
     * @return c the char representation of the input
     */
    function char(bytes1 b_) internal pure returns (bytes1 c) {
        if (uint8(b_) < 10) return bytes1(uint8(b_) + 0x30);
        else return bytes1(uint8(b_) + 0x57);
    }

    /**
     * @dev converts a string to bytes32
     * @param source_ the string to convert
     * @return stringAsBytes32 the bytes32 representation of the input
     */
    function toBytes32(string memory source_) internal pure returns (bytes32 stringAsBytes32) {
        bytes memory tempEmptyStringTest = bytes(source_);

        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            stringAsBytes32 := mload(add(source_, 32))
        }
    }
}
