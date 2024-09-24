import { describe, expect, it, beforeEach } from "vitest";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const contractOwner = accounts.get("deployer")!;

describe("CrowdWisdomBot", () => {
  beforeEach(() => {
    // Deploy the contract before each test
    simnet.deployContract("CrowdWisdomBot", contractOwner);
  });

  describe("Staking", () => {
    it("allows users to stake Bitcoin", () => {
      const { result } = simnet.callPublicFn("CrowdWisdomBot", "stake-bitcoin", [100n], address1);
      expect(result).toBeOk(true);
    });

    it("updates total staked amount", () => {
      simnet.callPublicFn("CrowdWisdomBot", "stake-bitcoin", [100n], address1);
      const { result } = simnet.callReadOnlyFn("CrowdWisdomBot", "get-total-staked", [], address1);
      expect(result).toBeOk(100n);
    });

    it("fails when user doesn't have enough funds", () => {
      const { result } = simnet.callPublicFn("CrowdWisdomBot", "stake-bitcoin", [1000000000000n], address1);
      expect(result).toBeErr(101n); // err-not-enough-funds
    });
  });

  describe("Voting", () => {
    beforeEach(() => {
      simnet.callPublicFn("CrowdWisdomBot", "stake-bitcoin", [100n], address1);
    });

    it("allows users to vote", () => {
      const { result } = simnet.callPublicFn("CrowdWisdomBot", "vote", ["buy"], address1);
      expect(result).toBeOk(true);
    });

    it("updates vote totals", () => {
      simnet.callPublicFn("CrowdWisdomBot", "vote", ["buy"], address1);
      const { result } = simnet.callReadOnlyFn("CrowdWisdomBot", "get-vote-total", ["buy"], address1);
      expect(result).toBeOk(100n);
    });

    it("fails when user has no stake", () => {
      const { result } = simnet.callPublicFn("CrowdWisdomBot", "vote", ["buy"], address2);
      expect(result).toBeErr(102n); // err-no-stake
    });

    it("fails with invalid vote option", () => {
      const { result } = simnet.callPublicFn("CrowdWisdomBot", "vote", ["invalid"], address1);
      expect(result).toBeErr(103n); // err-invalid-vote
    });
  });

  describe("Read-only functions", () => {
    beforeEach(() => {
      simnet.callPublicFn("CrowdWisdomBot", "stake-bitcoin", [100n], address1);
      simnet.callPublicFn("CrowdWisdomBot", "vote", ["buy"], address1);
    });

    it("returns the correct AI decision", () => {
      const { result } = simnet.callReadOnlyFn("CrowdWisdomBot", "get-ai-decision", [], address1);
      expect(result).toBeOk("hold");
    });

    it("returns the correct user stake", () => {
      const { result } = simnet.callReadOnlyFn("CrowdWisdomBot", "get-user-stake", [address1], address1);
      expect(result).toBeOk(100n);
    });

    it("returns the correct user vote", () => {
      const { result } = simnet.callReadOnlyFn("CrowdWisdomBot", "get-user-vote", [address1], address1);
      expect(result).toBeOk("buy");
    });
  });

  describe("Admin functions", () => {
    it("allows contract owner to update AI decision", () => {
      const { result } = simnet.callPublicFn("CrowdWisdomBot", "update-ai-decision", ["sell"], contractOwner);
      expect(result).toBeOk(true);
    });

    it("prevents non-owners from updating AI decision", () => {
      const { result } = simnet.callPublicFn("CrowdWisdomBot", "update-ai-decision", ["sell"], address1);
      expect(result).toBeErr(100n); // err-owner-only
    });
  });
});