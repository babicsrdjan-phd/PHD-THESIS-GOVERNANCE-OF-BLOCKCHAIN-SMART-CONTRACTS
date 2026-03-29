// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
 
import "@openzeppelin/contracts/access/Ownable.sol";
 
/**
 * @title   JointCommittee
 * @version 2.1.0
 * @notice  Implements CEFTA Joint Committee governance (Art. 40–41, CEFTA 2006).
 *          Provides proposal creation, per-member voting, and auto-execution
 *          lifecycle on a permissioned set of seven national delegates.
 * @dev     Audit fixes applied (v2.1.0):
 */
contract JointCommittee is Ownable {
 
    // ─── Data Structures ──────────────────────────────────────────────────────
 
    /// @notice On-chain record of a governance proposal.
    struct Proposal {
        string  description;   // human-readable motion text
        uint256 yesVotes;      // cumulative affirmative votes
        uint256 noVotes;       // cumulative negative votes
        bool    concluded;     // true once approved, defeated, or expired  
        uint256 createdAt;     // block.timestamp at proposal creation
        uint256 deadline;      // block.timestamp + PROPOSAL_DURATION  
    }
 
    // ─── State Variables ──────────────────────────────────────────────────────
 
    /// @notice One named delegate address per CEFTA party.
    address public albaniaDelegate;
    address public bosniaDelegate;
    address public kosovoDelegate;
    address public moldovaDelegate;
    address public montenegroDelegate;
    address public northMacedoniaDelegate;
    address public serbiaDelegate;
 
    /// @notice Total CEFTA voting parties — immutable by design.
    uint256 public constant MEMBER_COUNT = 7;
    /// @notice Default proposal lifetime before expiry may be triggered.  
    uint256 public constant PROPOSAL_DURATION = 72 hours;
 
    /// @notice Lookup: is this address a registered delegate?
    mapping(address => bool)   public votingMembers;
    /// @notice Lookup: delegate address → CEFTA party name string.
    mapping(address => string) public memberCountry;
    /// @notice All proposals, keyed by sequential ID.
    mapping(uint256 => Proposal) public proposals;
    /// @notice Double mapping: proposalId → delegate → has voted.
    mapping(uint256 => mapping(address => bool)) public voted;
    /// @notice Auto-incrementing proposal counter.
    uint256 public proposalCount;
 
    // ─── Events ───────────────────────────────────────────────────────────────
 
    /// @notice Emitted when a new proposal is submitted.  
    event ProposalCreated(uint256 indexed id, string description, uint256 deadline);
    /// @notice Emitted each time a delegate casts a vote.  
    event VoteCast(uint256 indexed id, string country, bool support);
    /// @notice Emitted when a proposal reaches majority approval.  
    event ProposalExecuted(uint256 indexed id);
    /// @notice Emitted when quorum met but majority absent (tie or rejection).
    event ProposalDefeated(uint256 indexed id);
    /// @notice Emitted when a proposal passes its deadline before full quorum.  
    event ProposalExpired(uint256 indexed id);
    /// @notice Emitted when the owner rotates a delegate address. 
    event DelegateUpdated(string country, address oldDelegate, address newDelegate);
 
    // ─── Constructor ─────────────────────────────────────────────────────────
 
    /**
     * @notice Deploys the contract, registers all seven CEFTA delegates.
     * @param initialOwner     Address that receives Ownable ownership (e.g. multisig).
     * @param _albania         Delegate address for Albania.
     * @param _bosnia          Delegate address for Bosnia and Herzegovina.
     * @param _kosovo          Delegate address for Kosovo.
     * @param _moldova         Delegate address for Moldova.
     * @param _montenegro      Delegate address for Montenegro.
     * @param _northMacedonia  Delegate address for North Macedonia.
     * @param _serbia          Delegate address for Serbia.
     */
    constructor(
        address initialOwner,
        address _albania,    address _bosnia,  address _kosovo,
        address _moldova,   address _montenegro,
        address _northMacedonia,  address _serbia
    ) Ownable(initialOwner) {
        albaniaDelegate        = _registerMember(_albania,        "Albania");
        bosniaDelegate         = _registerMember(_bosnia,         "Bosnia and Herzegovina");
        kosovoDelegate         = _registerMember(_kosovo,         "Kosovo");
        moldovaDelegate        = _registerMember(_moldova,        "Moldova");
        montenegroDelegate     = _registerMember(_montenegro,     "Montenegro");
        northMacedoniaDelegate = _registerMember(_northMacedonia, "North Macedonia");
        serbiaDelegate         = _registerMember(_serbia,         "Serbia");
    }
 
    // ─── Modifiers ────────────────────────────────────────────────────────────
 
    /// @dev Restricts access to registered CEFTA delegates only.
    modifier onlyMember() {
        require(votingMembers[msg.sender], "JC: not a CEFTA delegate");
        _;
    }
 
    // ─── External: Proposal Lifecycle ────────────────────────────────────────
 
    /**
     * @notice Submit a governance proposal for committee consideration.
     * @dev    Only registered delegates may propose (Art. 40, CEFTA 2006).
     * @param description  Plain-language text of the motion (non-empty).
     */
    function propose(string calldata description)  
        external
        onlyMember
    {
        require(bytes(description).length > 0, "JC: empty description");  
        uint256 id       = proposalCount;
        uint256 deadline = block.timestamp + PROPOSAL_DURATION;  
        proposals[id] = Proposal({                    
            description : description,
            yesVotes    : 0,
            noVotes     : 0,
            concluded   : false,
            createdAt   : block.timestamp,
            deadline    : deadline           
        });
        emit ProposalCreated(id, description, deadline);  
        proposalCount++;
    }
 
    /**
     * @notice Cast a yes/no vote on an open proposal.
     * @dev    Auto-executes when all MEMBER_COUNT delegates have voted.
     *         Checks-Effects-Interactions order maintained throughout.
     * @param proposalId  Sequential ID of the proposal to vote on.
     * @param support     true = yes vote; false = no vote.
     */
    function vote(uint256 proposalId, bool support)
        external
        onlyMember
    {
        require(proposalId < proposalCount,               "JC: proposal does not exist");
        require(!proposals[proposalId].concluded,          "JC: already concluded");  
        require(block.timestamp <= proposals[proposalId].deadline, "JC: proposal expired");  
        require(!voted[proposalId][msg.sender],           "JC: already voted");
 
        // --- Effects ---
        voted[proposalId][msg.sender] = true;
        if (support) {
            proposals[proposalId].yesVotes++;
        } else {
            proposals[proposalId].noVotes++;
        }
 
        string memory country = memberCountry[msg.sender];
        emit VoteCast(proposalId, country, support);  
 
        uint256 total = proposals[proposalId].yesVotes
                       + proposals[proposalId].noVotes;
        if (total == MEMBER_COUNT) {
            _conclude(proposalId);
        }
    }
 
    /**
     * @notice Mark a proposal expired once its deadline has passed.
     * @dev    Callable by any registered delegate — provides housekeeping
     *         incentive. Prevents indefinite blockage by non-voting delegates.
     * @param proposalId  ID of the proposal to expire.
     */
    function expireProposal(uint256 proposalId) external onlyMember {  
        require(proposalId < proposalCount,                  "JC: does not exist");
        require(!proposals[proposalId].concluded,             "JC: already concluded");
        require(block.timestamp > proposals[proposalId].deadline, "JC: deadline not passed");
        proposals[proposalId].concluded = true;
        emit ProposalExpired(proposalId);
    }
 
    // ─── External: Delegate Management ───────────────────────────────────────
 
    /**
     * @notice Rotate a delegate address for one CEFTA party.
     * @dev    Only the contract owner (e.g. committee secretariat multisig) may
     *         rotate delegates. Historical votes by the old address are preserved.
     */
    function updateDelegate(address old_, address new_)  
        external
        onlyOwner
    {
        require(votingMembers[old_],  "JC: not a current delegate");
        require(new_ != address(0),  "JC: zero address");
        require(!votingMembers[new_], "JC: already a delegate");
        string memory country = memberCountry[old_];
        votingMembers[old_] = false;
        memberCountry[old_] = "";
        votingMembers[new_] = true;
        memberCountry[new_] = country;
        _updateNamedPointer(old_, new_);
        emit DelegateUpdated(country, old_, new_);
    }
 
    // ─── External: View Helpers ──────────────────────────────────────────────
 
    /**
     * @notice Return all fields of a proposal in a single call.
     * @param proposalId  Sequential ID to query.
     * @return description  Motion text.
     * @return yesVotes     Cumulative affirmative votes cast so far.
     * @return noVotes      Cumulative negative votes cast so far.
     * @return concluded    True when the proposal lifecycle is closed.
     * @return createdAt    Block timestamp of proposal creation.
     * @return deadline     Block timestamp after which the proposal may expire.
     */
    function getProposal(uint256 proposalId)  
        external view
        returns (
            string memory description,
            uint256 yesVotes,
            uint256 noVotes,
            bool concluded,
            uint256 createdAt,
            uint256 deadline
        )
    {
        require(proposalId < proposalCount, "JC: does not exist");
        Proposal storage p = proposals[proposalId];
        return (p.description, p.yesVotes, p.noVotes,
                p.concluded, p.createdAt, p.deadline);
    }
 
    // ─── Internal Helpers ─────────────────────────────────────────────────────
 
    /**
     * @dev Validates and registers a delegate during construction.
     * @param delegate  Address to register.
     * @param country   Human-readable CEFTA party name.
     */
    function _registerMember(address delegate, string memory country)
        private returns (address)
    {
        require(delegate != address(0), "JC: zero address");
        require(!votingMembers[delegate], "JC: duplicate delegate");
        votingMembers[delegate] = true;
        memberCountry[delegate] = country;
        return delegate;
    }
 
    /**
     * @dev Called when totalVotes == MEMBER_COUNT.
     */
    function _conclude(uint256 proposalId) internal {
        Proposal storage p = proposals[proposalId];
        p.concluded = true;   
        if (p.yesVotes > p.noVotes) {
            emit ProposalExecuted(proposalId);  // majority approved
        } else {
            emit ProposalDefeated(proposalId);  // majority rejected or tie
        }
    }
 
    /**
     */
    function _updateNamedPointer(address o, address n) private {  
        if      (o == albaniaDelegate)        albaniaDelegate        = n;
        else if (o == bosniaDelegate)         bosniaDelegate         = n;
        else if (o == kosovoDelegate)         kosovoDelegate         = n;
        else if (o == moldovaDelegate)        moldovaDelegate        = n;
        else if (o == montenegroDelegate)     montenegroDelegate     = n;
        else if (o == northMacedoniaDelegate) northMacedoniaDelegate = n;
        else if (o == serbiaDelegate)         serbiaDelegate         = n;
    }
 
}

