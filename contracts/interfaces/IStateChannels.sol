// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStateChannels {
    function openChannel(address _counterparty, uint256 _amount) external returns (bytes32 channelId);
    function closeChannel(bytes32 _channelId) external;
    function updateChannelState(bytes32 _channelId, uint256 _newBalance) external;
    function getChannelBalance(bytes32 _channelId) external view returns (uint256);
}