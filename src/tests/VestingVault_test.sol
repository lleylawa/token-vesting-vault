// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../VestingVault.sol";
import "../MockToken.sol";
import "../UnauthorizedCaller.sol";

contract VestingVaultTest {
    MockToken token;
    VestingVault vault;

    function beforeEach() public {
        token = new MockToken();
        vault = new VestingVault(IERC20(address(token)));
        token.transfer(address(vault), 1000 ether);
    }

    function create(
        uint256 amount,
        uint64 start,
        uint64 cliff,
        uint64 duration,
        bool revocable
    ) internal returns (uint256) {
        return vault.createSchedule(address(0x1234), amount, start, cliff, duration, revocable);
    }

    function checkInitialState() public {
        Assert.equal(vault.scheduleCount(), uint256(0), "Initially no schedules");
        Assert.equal(vault.totalAllocated(), uint256(0), "Initially no allocation");
        Assert.equal(token.balanceOf(address(vault)), 1000 ether, "Vault funded");
    }

    function checkCreateSchedule() public {
        uint256 id = create(100 ether, uint64(block.timestamp), 0, 1000, true);
        Assert.equal(id, uint256(1), "First ID is 1");
        Assert.equal(vault.scheduleCount(), uint256(1), "One schedule");
        Assert.equal(vault.totalAllocated(), 100 ether, "100 tokens reserved");
    }

    function checkBeforeStart() public {
        uint256 id = create(100 ether, uint64(block.timestamp + 1000), 100, 2000, true);
        Assert.equal(vault.vestedAmount(id), uint256(0), "Nothing before start");
    }

    function checkDuringCliff() public {
        uint256 id = create(100 ether, uint64(block.timestamp - 100), 200, 1000, true);
        Assert.equal(vault.vestedAmount(id), uint256(0), "Nothing during cliff");
    }

    function checkExactlyAtCliff() public {
        uint256 id = create(100 ether, uint64(block.timestamp - 200), 200, 1000, true);
        Assert.equal(vault.vestedAmount(id), 20 ether, "Linear vesting begins at cliff");
    }

    function checkHalfVested() public {
        uint256 id = create(100 ether, uint64(block.timestamp - 500), 0, 1000, true);
        Assert.equal(vault.vestedAmount(id), 50 ether, "Half vested");
    }

    function checkAtEnd() public {
        uint256 id = create(100 ether, uint64(block.timestamp - 1000), 0, 1000, true);
        Assert.equal(vault.vestedAmount(id), 100 ether, "Fully vested at end");
    }

    function checkAfterEnd() public {
        uint256 id = create(100 ether, uint64(block.timestamp - 2000), 0, 1000, true);
        Assert.equal(vault.vestedAmount(id), 100 ether, "Fully vested after end");
    }

    function checkRelease() public {
        uint256 id = create(100 ether, uint64(block.timestamp - 2000), 0, 1000, true);
        uint256 beforeBalance = token.balanceOf(address(0x1234));
        vault.release(id);
        Assert.equal(token.balanceOf(address(0x1234)) - beforeBalance, 100 ether, "Beneficiary paid");
        Assert.equal(vault.releasable(id), uint256(0), "Nothing left to claim");
        Assert.equal(vault.totalAllocated(), uint256(0), "Allocation decreased");
    }

    function checkDoubleRelease() public {
        uint256 id = create(100 ether, uint64(block.timestamp - 2000), 0, 1000, true);
        vault.release(id);
        bool rejected;
        try vault.release(id) { rejected = false; } catch { rejected = true; }
        Assert.ok(rejected, "Second release rejected");
        Assert.equal(token.balanceOf(address(0x1234)), 100 ether, "No double payment");
    }

    function checkRevokeBeforeCliff() public {
        uint256 id = create(100 ether, uint64(block.timestamp + 1000), 200, 2000, true);
        uint256 beforeBalance = token.balanceOf(address(this));
        vault.revoke(id);
        Assert.equal(token.balanceOf(address(this)) - beforeBalance, 100 ether, "Unvested tokens refunded");
        Assert.equal(vault.releasable(id), uint256(0), "Nothing vested");
        Assert.equal(vault.totalAllocated(), uint256(0), "No remaining allocation");
    }

    function checkRevokeHalfVested() public {
        uint256 id = create(100 ether, uint64(block.timestamp - 500), 0, 1000, true);
        uint256 beforeBalance = token.balanceOf(address(this));
        vault.revoke(id);
        Assert.equal(vault.vestedAmount(id), 50 ether, "Vesting frozen at 50");
        Assert.equal(vault.releasable(id), 50 ether, "50 still claimable");
        Assert.equal(token.balanceOf(address(this)) - beforeBalance, 50 ether, "50 returned to owner");
        Assert.equal(vault.totalAllocated(), 50 ether, "50 reserved for beneficiary");
    }

    function checkReleaseAfterRevoke() public {
        uint256 id = create(100 ether, uint64(block.timestamp - 500), 0, 1000, true);
        vault.revoke(id);
        vault.release(id);
        Assert.equal(token.balanceOf(address(0x1234)), 50 ether, "Vested tokens paid after revoke");
        Assert.equal(vault.totalAllocated(), uint256(0), "No allocation remains");
    }

    function checkRevokeAfterEnd() public {
        uint256 id = create(100 ether, uint64(block.timestamp - 2000), 0, 1000, true);
        uint256 beforeBalance = token.balanceOf(address(this));
        vault.revoke(id);
        Assert.equal(token.balanceOf(address(this)), beforeBalance, "No refund after full vesting");
        Assert.equal(vault.releasable(id), 100 ether, "All tokens remain claimable");
    }

    function checkCannotRevokeNonrevocable() public {
        uint256 id = create(100 ether, uint64(block.timestamp), 0, 1000, false);
        bool rejected;
        try vault.revoke(id) { rejected = false; } catch { rejected = true; }
        Assert.ok(rejected, "Nonrevocable schedule protected");
    }

    function checkCannotRevokeTwice() public {
        uint256 id = create(100 ether, uint64(block.timestamp + 1000), 0, 2000, true);
        vault.revoke(id);
        bool rejected;
        try vault.revoke(id) { rejected = false; } catch { rejected = true; }
        Assert.ok(rejected, "Second revoke rejected");
    }

    function checkUnauthorizedCreate() public {
        UnauthorizedCaller attacker = new UnauthorizedCaller();
        bool rejected;
        try attacker.tryCreateSchedule(vault) { rejected = false; } catch { rejected = true; }
        Assert.ok(rejected, "Only owner can create");
        Assert.equal(vault.scheduleCount(), uint256(0), "No schedule created");
    }

    function checkUnauthorizedRevoke() public {
        uint256 id = create(100 ether, uint64(block.timestamp + 1000), 0, 2000, true);
        UnauthorizedCaller attacker = new UnauthorizedCaller();
        bool rejected;
        try attacker.tryRevoke(vault, id) { rejected = false; } catch { rejected = true; }
        Assert.ok(rejected, "Only owner can revoke");
    }

    function checkInsufficientBalance() public {
        bool rejected;
        try vault.createSchedule(address(0x1234), 2000 ether, 0, 0, 1000, true) {
            rejected = false;
        } catch { rejected = true; }
        Assert.ok(rejected, "Cannot overallocate tokens");
    }

    function checkZeroAmount() public {
        bool rejected;
        try vault.createSchedule(address(0x1234), 0, 0, 0, 1000, true) {
            rejected = false;
        } catch { rejected = true; }
        Assert.ok(rejected, "Zero amount rejected");
    }

    function checkZeroBeneficiary() public {
        bool rejected;
        try vault.createSchedule(address(0), 100 ether, 0, 0, 1000, true) {
            rejected = false;
        } catch { rejected = true; }
        Assert.ok(rejected, "Zero beneficiary rejected");
    }

    function checkInvalidDurationAndCliff() public {
        bool zeroDurationRejected;
        try vault.createSchedule(address(0x1234), 100 ether, 0, 0, 0, true) {
            zeroDurationRejected = false;
        } catch { zeroDurationRejected = true; }
        Assert.ok(zeroDurationRejected, "Zero duration rejected");

        bool cliffRejected;
        try vault.createSchedule(address(0x1234), 100 ether, 0, 1001, 1000, true) {
            cliffRejected = false;
        } catch { cliffRejected = true; }
        Assert.ok(cliffRejected, "Cliff longer than duration rejected");
    }

    function checkWithdrawUnallocated() public {
        create(300 ether, uint64(block.timestamp + 1000), 0, 2000, true);
        uint256 beforeBalance = token.balanceOf(address(this));
        vault.withdrawUnallocated(address(this));
        Assert.equal(token.balanceOf(address(this)) - beforeBalance, 700 ether, "Only unallocated tokens withdrawn");
        Assert.equal(token.balanceOf(address(vault)), 300 ether, "Allocated tokens remain in vault");
    }

    function checkSchedulesOf() public {
        uint256 id = create(100 ether, uint64(block.timestamp), 0, 1000, true);
        uint256[] memory ids = vault.schedulesOf(address(0x1234));
        Assert.equal(ids.length, uint256(1), "One beneficiary schedule");
        Assert.equal(ids[0], id, "Correct schedule ID");
    }

    function checkTransferSchedule() public {
        // The test contract is the beneficiary, so it can transfer the schedule.
        uint256 id = vault.createSchedule(address(this), 100 ether, uint64(block.timestamp), 0, 1000, true);
        vault.transferSchedule(id, address(0x9999));
        uint256[] memory oldIds = vault.schedulesOf(address(this));
        uint256[] memory newIds = vault.schedulesOf(address(0x9999));
        Assert.equal(oldIds.length, uint256(0), "Removed from old beneficiary");
        Assert.equal(newIds.length, uint256(1), "Added to new beneficiary");
        Assert.equal(newIds[0], id, "Correct transferred schedule");
    }

    function checkSeveralAmounts() public {
        // Fixed-value property checks, NOT randomized fuzzing.
        uint256[5] memory amounts = [uint256(1), 7, 100, 1000, 10000];
        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 id = create(amounts[i], uint64(block.timestamp - 500), 0, 1000, true);
            Assert.equal(vault.vestedAmount(id), amounts[i] / 2, "Half of each amount vested (rounded down)");
        }
    }
}
