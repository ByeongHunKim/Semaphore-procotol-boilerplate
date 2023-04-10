//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ISemaphore.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ERC721 {
    function balanceOf(address owner) external view returns (uint256 balance);
}

contract Feedback is Ownable {
    error Feedback_UsernameAlreadyExists(); // error 선언
    error Feedback_GroupIdAlreadyExists(); // error 선언

    event NewFeedback(uint feedback); // 피드백 발생 시 이벤트
    event NewUser(uint identifyCommitment, bytes32 userName); // joinGroup했을 때 이벤트
    event NewGroup(uint groupId, bytes32 groupName);

    ISemaphore public semaphore;
    address public nftAddress; // constructor로 배포할 때 주입할 nftContract address
    uint public groupId = 2; // 현재 semaphore 컨트랙트에 2가 마지막 그룹이어서 3으로 해야함
    uint constant MERKLE_TREE_DEPTH = 20; // 머클트리 depth를 의미하는데, 정확히 어떻게 쓰이는 지 알아야함
    mapping(uint => bytes32) public users; // identify commitment - username 매핑 ++ 지금은 계정이 값들을 기억하고 있지 못하는데, 어떻게 처리할지
    mapping(uint => bytes32) public groups; // groupId - groupname 매핑

    constructor(address _semaphoreAddress, address _nftAddress) {
        semaphore = ISemaphore(_semaphoreAddress);
        nftAddress = _nftAddress;
    }

    function createGroup(bytes32 _groupName) external onlyOwner { // onlyOwner? 또는 크립토버미처럼 관리자주소를 매핑넣고 modifier지정
        groupId++;
        groups[groupId] = _groupName;
        semaphore.createGroup(groupId, MERKLE_TREE_DEPTH, address(this));
        emit NewGroup(groupId, _groupName);
    }

    function joinGroup(uint _groupId, uint _identityCommitment, bytes32 _username) external { // _groupId를 어떻게 컨트랙트 함수 파라미터에 넣을 것 인가? (그룹별로 groupId 값을 저장해야함)
        ERC721 nftContract = ERC721(nftAddress);
        require(nftContract.balanceOf(msg.sender) > 0, "you dont have NFT");
        if (users[_identityCommitment] != 0) { // UI에서 입력한 identityCommitment를(key) 값이 username 보유하고 있는 경우 예외처리
            revert Feedback_UsernameAlreadyExists();
        } else if(groups[_groupId] != 0) { // groupId(key)값이 groupname을 보유하고 있지 않는 경우는 그룹생성이 안된거라 예외처리
            revert Feedback_GroupIdAlreadyExists();
        }
        semaphore.addMember(_groupId, _identityCommitment); // 현재는 groupId이 늘어나면 그대로 모두 다 바뀜(이슈) -> 그래서 최초1회만 createGroup해야함
        users[_identityCommitment] = _username;
        emit NewUser(_identityCommitment, _username);
    }

    function sendFeedback(
        uint feedback,
        uint merkleTreeRoot,
        uint nullifierHash,
        uint[8] calldata proof
    ) external {
        semaphore.verifyProof(groupId, merkleTreeRoot, feedback, nullifierHash, groupId, proof);
        emit NewFeedback(feedback);
    }

    function setNftAddress(address _newNftAddress) external onlyOwner {
        nftAddress = _newNftAddress;
    }

}
