// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./DssSoul.sol";

contract DssSoulTest is DSTest {
    DssSoul soul;

    function setUp() public {
        soul = new DssSoul();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
