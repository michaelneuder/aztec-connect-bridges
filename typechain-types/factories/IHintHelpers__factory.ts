/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import { Provider } from "@ethersproject/providers";
import type { IHintHelpers, IHintHelpersInterface } from "../IHintHelpers";

const _abi = [
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_CR",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_numTrials",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_inputRandomSeed",
        type: "uint256",
      },
    ],
    name: "getApproxHint",
    outputs: [
      {
        internalType: "address",
        name: "hintAddress",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "diff",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "latestRandomSeed",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

export class IHintHelpers__factory {
  static readonly abi = _abi;
  static createInterface(): IHintHelpersInterface {
    return new utils.Interface(_abi) as IHintHelpersInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IHintHelpers {
    return new Contract(address, _abi, signerOrProvider) as IHintHelpers;
  }
}
