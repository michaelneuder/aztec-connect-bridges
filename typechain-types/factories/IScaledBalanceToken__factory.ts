/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import { Provider } from "@ethersproject/providers";
import type {
  IScaledBalanceToken,
  IScaledBalanceTokenInterface,
} from "../IScaledBalanceToken";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "scaledBalanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "underlying",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

export class IScaledBalanceToken__factory {
  static readonly abi = _abi;
  static createInterface(): IScaledBalanceTokenInterface {
    return new utils.Interface(_abi) as IScaledBalanceTokenInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): IScaledBalanceToken {
    return new Contract(address, _abi, signerOrProvider) as IScaledBalanceToken;
  }
}
