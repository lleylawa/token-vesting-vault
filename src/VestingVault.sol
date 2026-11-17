
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title VestingVault — token vesting with cliff, linear unlock and revocation (STUDENT STARTER)
/// @notice One vault holds tokens for many beneficiaries. The owner (e.g. the project team)
///         creates schedules; beneficiaries (team, investors, advisors) receive tokens over time.
contract VestingVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============================================================
    //  PROVIDED PART (identical to the student starter file)
    // ============================================================
    struct Schedule {
        address beneficiary;
        uint256 total;
        uint256 released;
        uint64 start;
        uint64 cliff;
        uint64 duration;
        uint64 revokedAt;
        bool revocable;
        bool revoked;
    }

    IERC20 public immutable token;
    uint256 public scheduleCount;
    uint256 public totalAllocated;
    mapping(uint256 => Schedule) public schedules;
    mapping(address => uint256[]) private _schedulesOf;

    event ScheduleCreated(uint256 indexed id, address indexed beneficiary, uint256 amount, uint64 start, uint64 cliff, uint64 duration, bool revocable);
    event Released(uint256 indexed id, address indexed beneficiary, uint256 amount);
    event Revoked(uint256 indexed id, uint256 returnedToOwner);
    event ScheduleTransferred(uint256 indexed id, address indexed from, address indexed to);

    constructor(IERC20 token_) Ownable(msg.sender) {
        require(address(token_) != address(0), "zero token");
        token = token_;
    }

    // ============================================================
    //  YOUR CODE STARTS HERE
    // ============================================================

    /// @notice Creates a vesting schedule for a beneficiary.
    /// @param beneficiary Address receiving the tokens.
    /// @param amount Total tokens allocated.
    /// @param start Vesting start timestamp.
    /// @param cliff Seconds before the first unlock.
    /// @param duration Total vesting duration in seconds.
    /// @param revocable Whether the owner can revoke the schedule.
    /// @return id The new schedule identifier.
    function createSchedule(
        address beneficiary,
        uint256 amount,
        uint64 start,
        uint64 cliff,
        uint64 duration,
        bool revocable
    ) external onlyOwner returns (uint256 id) {
        require(beneficiary != address(0), "zero beneficiary");
        require(amount > 0, "zero amount");
        require(duration > 0, "zero duration");
        require(cliff <= duration, "cliff exceeds duration");

        uint256 balance = token.balanceOf(address(this));
        require(balance >= totalAllocated, "insufficient balance");
        require(balance - totalAllocated >= amount, "insufficient tokens");

        id = ++scheduleCount;

        schedules[id] = Schedule({
            beneficiary: beneficiary,
            total: amount,
            released: 0,
            start: start,
            cliff: cliff,
            duration: duration,
            revokedAt: 0,
            revocable: revocable,
            revoked: false
        });

        _schedulesOf[beneficiary].push(id);
        totalAllocated += amount;

        emit ScheduleCreated(
            id,
            beneficiary,
            amount,
            start,
            cliff,
            duration,
            revocable
        );

        return id;
    }

    /// @notice Calculates the total vested tokens for a schedule.
    /// @param id Schedule identifier.
    /// @return The total vested amount.
    function vestedAmount(uint256 id) public view returns (uint256) {
        require(id > 0 && id <= scheduleCount, "Unknown schedule");

        Schedule storage s = schedules[id];

        uint256 t = s.revoked
            ? uint256(s.revokedAt)
            : block.timestamp;

        if (t < uint256(s.start) + uint256(s.cliff)) {
            return 0;
        }

        if (t >= uint256(s.start) + uint256(s.duration)) {
            return s.total;
        }

        return (s.total * (t - uint256(s.start))) / uint256(s.duration);
    }

    /// @notice Returns tokens currently available for withdrawal.
    /// @param id Schedule identifier.
    /// @return Amount available for release.
    function releasable(uint256 id) public view returns (uint256) {
        require(id > 0 && id <= scheduleCount, "Unknown schedule");

        uint256 vested = vestedAmount(id);
        uint256 released = schedules[id].released;

        return vested - released;
    }

    /// @notice Transfers available tokens to the beneficiary.
    /// @param id Schedule identifier.
    function release(uint256 id) external nonReentrant {
        require(id > 0 && id <= scheduleCount, "Unknown schedule");

        Schedule storage s = schedules[id];

        uint256 amount = releasable(id);
        require(amount > 0, "Nothing to release");

        s.released += amount;
        totalAllocated -= amount;

        token.safeTransfer(s.beneficiary, amount);

        emit Released(id, s.beneficiary, amount);
    }

    /// @notice Revokes a schedule and returns unvested tokens to the owner.
    /// @param id Schedule identifier.
    function revoke(uint256 id) external onlyOwner nonReentrant {
        require(id > 0 && id <= scheduleCount, "Unknown schedule");

        Schedule storage s = schedules[id];

        require(s.revocable, "Not revocable");
        require(!s.revoked, "Already revoked");

        uint256 vested = vestedAmount(id);
        uint256 unvested = s.total - vested;

        s.revoked = true;
        s.revokedAt = uint64(block.timestamp);

        totalAllocated -= unvested;

        if (unvested > 0) {
            token.safeTransfer(owner(), unvested);
        }

        emit Revoked(id, unvested);
    }

    /// @notice Withdraws tokens not allocated to any schedule.
    /// @param to Address receiving the unallocated tokens.
    /// @return amount Number of tokens withdrawn.
    function withdrawUnallocated(address to)
        external
        onlyOwner
        nonReentrant
        returns (uint256 amount)
    {
        require(to != address(0), "Zero address");

        uint256 balance = token.balanceOf(address(this));
        require(balance >= totalAllocated, "Insufficient balance");

        amount = balance - totalAllocated;
        require(amount > 0, "Nothing to withdraw");

        token.safeTransfer(to, amount);

        return amount;
    }

    /// @notice Lists the schedules currently owned by a beneficiary.
    /// @param beneficiary Address of the beneficiary.
    /// @return Array of schedule identifiers.
    function schedulesOf(address beneficiary)
        external
        view
        returns (uint256[] memory)
    {
        return _schedulesOf[beneficiary];
    }

    /// @notice Transfers a schedule to another beneficiary.
    /// @param id Schedule identifier.
    /// @param newBeneficiary Address of the new beneficiary.
    function transferSchedule(uint256 id, address newBeneficiary)
        external
    {
        require(id > 0 && id <= scheduleCount, "Unknown schedule");
        require(newBeneficiary != address(0), "Zero address");

        Schedule storage s = schedules[id];

        require(msg.sender == s.beneficiary, "Not beneficiary");

        address oldBeneficiary = s.beneficiary;

        require(newBeneficiary != oldBeneficiary, "Same beneficiary");

        uint256[] storage oldSchedules = _schedulesOf[oldBeneficiary];

        for (uint256 i = 0; i < oldSchedules.length; i++) {
            if (oldSchedules[i] == id) {
                oldSchedules[i] = oldSchedules[oldSchedules.length - 1];
                oldSchedules.pop();
                break;
            }
        }

        s.beneficiary = newBeneficiary;
        _schedulesOf[newBeneficiary].push(id);

        emit ScheduleTransferred(
            id,
            oldBeneficiary,
            newBeneficiary
        );
    }
}
