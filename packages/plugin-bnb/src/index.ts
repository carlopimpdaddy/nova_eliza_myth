export * from "./actions/swap";
export * from "./actions/transfer";
export * from "./providers/wallet";
export * from "./types";

import type { Plugin } from "@elizaos/core";
import { swapAction } from "./actions/swap";
import { transferAction } from "./actions/transfer";
import { bnbWalletProvider } from "./providers/wallet";
import { getBalanceAction } from "./actions/getBalance";
import { bridgeAction } from "./actions/bridge";
import { stakeAction } from "./actions/stake";
import { faucetAction } from "./actions/faucet";
import { deployAction } from "./actions/deploy";

export const bnbPlugin: Plugin = {
    name: "bnb",
    description: "BNB Chain Plugin for Eliza",
    actions: [],
    providers: []
};

export default bnbPlugin;
