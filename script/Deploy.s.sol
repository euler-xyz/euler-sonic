// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {EulerRouter} from "epo/EulerRouter.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {HookTargetAccessControl} from "evk-periphery/HookTarget/HookTargetAccessControl.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IEulerRouterFactory} from "evk-periphery/EulerRouterFactory/interfaces/IEulerRouterFactory.sol";
import "evk/EVault/shared/Constants.sol";

contract DeploymentScript is Script {
    // addresses taken from https://github.com/euler-xyz/euler-interfaces/tree/master/addresses/146
    address internal constant EVC = 0x4860C903f6Ad709c3eDA46D3D502943f184D4315;
    IEulerRouterFactory internal constant eulerRouterFactory =
        IEulerRouterFactory(0xc5b9B95a769C24c18c344c2659db61a0AdFB736E);
    GenericFactory internal constant eVaultFactory = GenericFactory(0xF075cC8660B51D0b8a4474e3f47eDAC5fA034cFB);

    // asset addresses
    address internal constant wS = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
    address internal constant stS = 0xE5DA20F15420aD15DE0fa650600aFc998bbE3955;

    // predeployed oracle adapters
    // https://oracles.euler.finance/146/adapter/0xd396d5080490Cab4b491552ABd18f4Cd7A1D86dE/
    address internal constant stS_wS_RedstoneFundamental = 0xd396d5080490Cab4b491552ABd18f4Cd7A1D86dE;

    // predeployed adaptive curve IRM address
    address internal constant IRM = 0x8394A647e9Ea742920406334eDE8C1dbAEA9Cb12;

    // vault parameters
    uint16 internal constant LIQUIDATION_COOL_OFF_TIME = 1;
    uint16 internal constant MAX_LIQUIDATION_DISCOUNT = 0.15e4;
    uint16 internal constant BORROW_LTV = 0.95e4;
    uint16 internal constant LIQUIDATION_LTV = 0.97e4;

    // hook target parameters
    address internal constant HOOK_TARGET_GOVERNOR = // TODO

    function run() public virtual {
        vm.startBroadcast();

        // deploy and configure the oracle router
        EulerRouter oracleRouter = EulerRouter(eulerRouterFactory.deploy(vm.getWallets()[0]));
        oracleRouter.govSetConfig(stS, wS, stS_wS_RedstoneFundamental);

        // deploy and configure the stS vault
        IEVault estS =
            IEVault(eVaultFactory.createProxy(address(0), false, abi.encodePacked(stS, address(0), address(0))));
        oracleRouter.govSetResolvedVault(address(estS), true);
        estS.setHookConfig(address(0), 0);

        // deploy and configure the wS vault
        IEVault ewS = IEVault(eVaultFactory.createProxy(address(0), false, abi.encodePacked(wS, oracleRouter, wS)));
        ewS.setLiquidationCoolOffTime(LIQUIDATION_COOL_OFF_TIME);
        ewS.setMaxLiquidationDiscount(MAX_LIQUIDATION_DISCOUNT);
        ewS.setInterestRateModel(IRM);
        ewS.setLTV(address(estS), BORROW_LTV, LIQUIDATION_LTV, 0);
        ewS.setHookConfig(
            address(new HookTargetAccessControl(EVC, HOOK_TARGET_GOVERNOR, address(eVaultFactory))),
            OP_BORROW | OP_PULL_DEBT | OP_FLASHLOAN
        );

        // transfer the governance
        oracleRouter.transferGovernance(address(0));
        ewS.setGovernorAdmin(address(0));
        ewS.setGovernorAdmin(address(0));

        vm.stopBroadcast();
    }
}
