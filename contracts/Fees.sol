//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;
library Fees {
    struct Fee {
        uint numerator;
        uint denominator;
    }
    function feesOf(uint value, Fee storage fee) internal view returns(uint) {
        return fee.denominator > 0 ? (value * fee.numerator) / fee.denominator : 0;
    }
}