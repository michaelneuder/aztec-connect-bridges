/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PayableOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import { FunctionFragment, Result, EventFragment } from "@ethersproject/abi";
import { Listener, Provider } from "@ethersproject/providers";
import { TypedEventFilter, TypedEvent, TypedListener, OnEvent } from "./common";

export declare namespace AztecTypes {
  export type AztecAssetStruct = {
    id: BigNumberish;
    erc20Address: string;
    assetType: BigNumberish;
  };

  export type AztecAssetStructOutput = [BigNumber, string, number] & {
    id: BigNumber;
    erc20Address: string;
    assetType: number;
  };
}

export interface RollupProcessorInterface extends utils.Interface {
  contractName: "RollupProcessor";
  functions: {
    "IS_TEST()": FunctionFragment;
    "convert(address,(uint256,address,uint8),(uint256,address,uint8),(uint256,address,uint8),(uint256,address,uint8),uint256,uint256,uint256)": FunctionFragment;
    "failed()": FunctionFragment;
    "processAsyncDefiInteraction(uint256)": FunctionFragment;
    "receiveEthFromBridge(uint256)": FunctionFragment;
    "setBridgeGasLimit(address,uint256)": FunctionFragment;
  };

  encodeFunctionData(functionFragment: "IS_TEST", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "convert",
    values: [
      string,
      AztecTypes.AztecAssetStruct,
      AztecTypes.AztecAssetStruct,
      AztecTypes.AztecAssetStruct,
      AztecTypes.AztecAssetStruct,
      BigNumberish,
      BigNumberish,
      BigNumberish
    ]
  ): string;
  encodeFunctionData(functionFragment: "failed", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "processAsyncDefiInteraction",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "receiveEthFromBridge",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "setBridgeGasLimit",
    values: [string, BigNumberish]
  ): string;

  decodeFunctionResult(functionFragment: "IS_TEST", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "convert", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "failed", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "processAsyncDefiInteraction",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "receiveEthFromBridge",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setBridgeGasLimit",
    data: BytesLike
  ): Result;

  events: {
    "AsyncDefiBridgeProcessed(uint256,uint256,uint256,uint256,uint256,bool)": EventFragment;
    "DefiBridgeProcessed(uint256,uint256,uint256,uint256,uint256,bool)": EventFragment;
    "log(string)": EventFragment;
    "log_address(address)": EventFragment;
    "log_bytes(bytes)": EventFragment;
    "log_bytes32(bytes32)": EventFragment;
    "log_int(int256)": EventFragment;
    "log_named_address(string,address)": EventFragment;
    "log_named_bytes(string,bytes)": EventFragment;
    "log_named_bytes32(string,bytes32)": EventFragment;
    "log_named_decimal_int(string,int256,uint256)": EventFragment;
    "log_named_decimal_uint(string,uint256,uint256)": EventFragment;
    "log_named_int(string,int256)": EventFragment;
    "log_named_string(string,string)": EventFragment;
    "log_named_uint(string,uint256)": EventFragment;
    "log_string(string)": EventFragment;
    "log_uint(uint256)": EventFragment;
    "logs(bytes)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "AsyncDefiBridgeProcessed"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "DefiBridgeProcessed"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_address"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_bytes"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_bytes32"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_int"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_address"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_bytes"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_bytes32"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_decimal_int"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_decimal_uint"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_int"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_string"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_named_uint"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_string"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "log_uint"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "logs"): EventFragment;
}

export type AsyncDefiBridgeProcessedEvent = TypedEvent<
  [BigNumber, BigNumber, BigNumber, BigNumber, BigNumber, boolean],
  {
    bridgeId: BigNumber;
    nonce: BigNumber;
    totalInputValue: BigNumber;
    totalOutputValueA: BigNumber;
    totalOutputValueB: BigNumber;
    result: boolean;
  }
>;

export type AsyncDefiBridgeProcessedEventFilter =
  TypedEventFilter<AsyncDefiBridgeProcessedEvent>;

export type DefiBridgeProcessedEvent = TypedEvent<
  [BigNumber, BigNumber, BigNumber, BigNumber, BigNumber, boolean],
  {
    bridgeId: BigNumber;
    nonce: BigNumber;
    totalInputValue: BigNumber;
    totalOutputValueA: BigNumber;
    totalOutputValueB: BigNumber;
    result: boolean;
  }
>;

export type DefiBridgeProcessedEventFilter =
  TypedEventFilter<DefiBridgeProcessedEvent>;

export type logEvent = TypedEvent<[string], { arg0: string }>;

export type logEventFilter = TypedEventFilter<logEvent>;

export type log_addressEvent = TypedEvent<[string], { arg0: string }>;

export type log_addressEventFilter = TypedEventFilter<log_addressEvent>;

export type log_bytesEvent = TypedEvent<[string], { arg0: string }>;

export type log_bytesEventFilter = TypedEventFilter<log_bytesEvent>;

export type log_bytes32Event = TypedEvent<[string], { arg0: string }>;

export type log_bytes32EventFilter = TypedEventFilter<log_bytes32Event>;

export type log_intEvent = TypedEvent<[BigNumber], { arg0: BigNumber }>;

export type log_intEventFilter = TypedEventFilter<log_intEvent>;

export type log_named_addressEvent = TypedEvent<
  [string, string],
  { key: string; val: string }
>;

export type log_named_addressEventFilter =
  TypedEventFilter<log_named_addressEvent>;

export type log_named_bytesEvent = TypedEvent<
  [string, string],
  { key: string; val: string }
>;

export type log_named_bytesEventFilter = TypedEventFilter<log_named_bytesEvent>;

export type log_named_bytes32Event = TypedEvent<
  [string, string],
  { key: string; val: string }
>;

export type log_named_bytes32EventFilter =
  TypedEventFilter<log_named_bytes32Event>;

export type log_named_decimal_intEvent = TypedEvent<
  [string, BigNumber, BigNumber],
  { key: string; val: BigNumber; decimals: BigNumber }
>;

export type log_named_decimal_intEventFilter =
  TypedEventFilter<log_named_decimal_intEvent>;

export type log_named_decimal_uintEvent = TypedEvent<
  [string, BigNumber, BigNumber],
  { key: string; val: BigNumber; decimals: BigNumber }
>;

export type log_named_decimal_uintEventFilter =
  TypedEventFilter<log_named_decimal_uintEvent>;

export type log_named_intEvent = TypedEvent<
  [string, BigNumber],
  { key: string; val: BigNumber }
>;

export type log_named_intEventFilter = TypedEventFilter<log_named_intEvent>;

export type log_named_stringEvent = TypedEvent<
  [string, string],
  { key: string; val: string }
>;

export type log_named_stringEventFilter =
  TypedEventFilter<log_named_stringEvent>;

export type log_named_uintEvent = TypedEvent<
  [string, BigNumber],
  { key: string; val: BigNumber }
>;

export type log_named_uintEventFilter = TypedEventFilter<log_named_uintEvent>;

export type log_stringEvent = TypedEvent<[string], { arg0: string }>;

export type log_stringEventFilter = TypedEventFilter<log_stringEvent>;

export type log_uintEvent = TypedEvent<[BigNumber], { arg0: BigNumber }>;

export type log_uintEventFilter = TypedEventFilter<log_uintEvent>;

export type logsEvent = TypedEvent<[string], { arg0: string }>;

export type logsEventFilter = TypedEventFilter<logsEvent>;

export interface RollupProcessor extends BaseContract {
  contractName: "RollupProcessor";
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: RollupProcessorInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    IS_TEST(overrides?: CallOverrides): Promise<[boolean]>;

    convert(
      bridgeAddress: string,
      inputAssetA: AztecTypes.AztecAssetStruct,
      inputAssetB: AztecTypes.AztecAssetStruct,
      outputAssetA: AztecTypes.AztecAssetStruct,
      outputAssetB: AztecTypes.AztecAssetStruct,
      totalInputValue: BigNumberish,
      interactionNonce: BigNumberish,
      auxInputData: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    failed(overrides?: CallOverrides): Promise<[boolean]>;

    processAsyncDefiInteraction(
      interactionNonce: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    receiveEthFromBridge(
      interactionNonce: BigNumberish,
      overrides?: PayableOverrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    setBridgeGasLimit(
      bridgeAddress: string,
      gasLimit: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;
  };

  IS_TEST(overrides?: CallOverrides): Promise<boolean>;

  convert(
    bridgeAddress: string,
    inputAssetA: AztecTypes.AztecAssetStruct,
    inputAssetB: AztecTypes.AztecAssetStruct,
    outputAssetA: AztecTypes.AztecAssetStruct,
    outputAssetB: AztecTypes.AztecAssetStruct,
    totalInputValue: BigNumberish,
    interactionNonce: BigNumberish,
    auxInputData: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  failed(overrides?: CallOverrides): Promise<boolean>;

  processAsyncDefiInteraction(
    interactionNonce: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  receiveEthFromBridge(
    interactionNonce: BigNumberish,
    overrides?: PayableOverrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  setBridgeGasLimit(
    bridgeAddress: string,
    gasLimit: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  callStatic: {
    IS_TEST(overrides?: CallOverrides): Promise<boolean>;

    convert(
      bridgeAddress: string,
      inputAssetA: AztecTypes.AztecAssetStruct,
      inputAssetB: AztecTypes.AztecAssetStruct,
      outputAssetA: AztecTypes.AztecAssetStruct,
      outputAssetB: AztecTypes.AztecAssetStruct,
      totalInputValue: BigNumberish,
      interactionNonce: BigNumberish,
      auxInputData: BigNumberish,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber, boolean] & {
        outputValueA: BigNumber;
        outputValueB: BigNumber;
        isAsync: boolean;
      }
    >;

    failed(overrides?: CallOverrides): Promise<boolean>;

    processAsyncDefiInteraction(
      interactionNonce: BigNumberish,
      overrides?: CallOverrides
    ): Promise<boolean>;

    receiveEthFromBridge(
      interactionNonce: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;

    setBridgeGasLimit(
      bridgeAddress: string,
      gasLimit: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;
  };

  filters: {
    "AsyncDefiBridgeProcessed(uint256,uint256,uint256,uint256,uint256,bool)"(
      bridgeId?: BigNumberish | null,
      nonce?: BigNumberish | null,
      totalInputValue?: null,
      totalOutputValueA?: null,
      totalOutputValueB?: null,
      result?: null
    ): AsyncDefiBridgeProcessedEventFilter;
    AsyncDefiBridgeProcessed(
      bridgeId?: BigNumberish | null,
      nonce?: BigNumberish | null,
      totalInputValue?: null,
      totalOutputValueA?: null,
      totalOutputValueB?: null,
      result?: null
    ): AsyncDefiBridgeProcessedEventFilter;

    "DefiBridgeProcessed(uint256,uint256,uint256,uint256,uint256,bool)"(
      bridgeId?: BigNumberish | null,
      nonce?: BigNumberish | null,
      totalInputValue?: null,
      totalOutputValueA?: null,
      totalOutputValueB?: null,
      result?: null
    ): DefiBridgeProcessedEventFilter;
    DefiBridgeProcessed(
      bridgeId?: BigNumberish | null,
      nonce?: BigNumberish | null,
      totalInputValue?: null,
      totalOutputValueA?: null,
      totalOutputValueB?: null,
      result?: null
    ): DefiBridgeProcessedEventFilter;

    "log(string)"(arg0?: null): logEventFilter;
    log(arg0?: null): logEventFilter;

    "log_address(address)"(arg0?: null): log_addressEventFilter;
    log_address(arg0?: null): log_addressEventFilter;

    "log_bytes(bytes)"(arg0?: null): log_bytesEventFilter;
    log_bytes(arg0?: null): log_bytesEventFilter;

    "log_bytes32(bytes32)"(arg0?: null): log_bytes32EventFilter;
    log_bytes32(arg0?: null): log_bytes32EventFilter;

    "log_int(int256)"(arg0?: null): log_intEventFilter;
    log_int(arg0?: null): log_intEventFilter;

    "log_named_address(string,address)"(
      key?: null,
      val?: null
    ): log_named_addressEventFilter;
    log_named_address(key?: null, val?: null): log_named_addressEventFilter;

    "log_named_bytes(string,bytes)"(
      key?: null,
      val?: null
    ): log_named_bytesEventFilter;
    log_named_bytes(key?: null, val?: null): log_named_bytesEventFilter;

    "log_named_bytes32(string,bytes32)"(
      key?: null,
      val?: null
    ): log_named_bytes32EventFilter;
    log_named_bytes32(key?: null, val?: null): log_named_bytes32EventFilter;

    "log_named_decimal_int(string,int256,uint256)"(
      key?: null,
      val?: null,
      decimals?: null
    ): log_named_decimal_intEventFilter;
    log_named_decimal_int(
      key?: null,
      val?: null,
      decimals?: null
    ): log_named_decimal_intEventFilter;

    "log_named_decimal_uint(string,uint256,uint256)"(
      key?: null,
      val?: null,
      decimals?: null
    ): log_named_decimal_uintEventFilter;
    log_named_decimal_uint(
      key?: null,
      val?: null,
      decimals?: null
    ): log_named_decimal_uintEventFilter;

    "log_named_int(string,int256)"(
      key?: null,
      val?: null
    ): log_named_intEventFilter;
    log_named_int(key?: null, val?: null): log_named_intEventFilter;

    "log_named_string(string,string)"(
      key?: null,
      val?: null
    ): log_named_stringEventFilter;
    log_named_string(key?: null, val?: null): log_named_stringEventFilter;

    "log_named_uint(string,uint256)"(
      key?: null,
      val?: null
    ): log_named_uintEventFilter;
    log_named_uint(key?: null, val?: null): log_named_uintEventFilter;

    "log_string(string)"(arg0?: null): log_stringEventFilter;
    log_string(arg0?: null): log_stringEventFilter;

    "log_uint(uint256)"(arg0?: null): log_uintEventFilter;
    log_uint(arg0?: null): log_uintEventFilter;

    "logs(bytes)"(arg0?: null): logsEventFilter;
    logs(arg0?: null): logsEventFilter;
  };

  estimateGas: {
    IS_TEST(overrides?: CallOverrides): Promise<BigNumber>;

    convert(
      bridgeAddress: string,
      inputAssetA: AztecTypes.AztecAssetStruct,
      inputAssetB: AztecTypes.AztecAssetStruct,
      outputAssetA: AztecTypes.AztecAssetStruct,
      outputAssetB: AztecTypes.AztecAssetStruct,
      totalInputValue: BigNumberish,
      interactionNonce: BigNumberish,
      auxInputData: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    failed(overrides?: CallOverrides): Promise<BigNumber>;

    processAsyncDefiInteraction(
      interactionNonce: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    receiveEthFromBridge(
      interactionNonce: BigNumberish,
      overrides?: PayableOverrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    setBridgeGasLimit(
      bridgeAddress: string,
      gasLimit: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    IS_TEST(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    convert(
      bridgeAddress: string,
      inputAssetA: AztecTypes.AztecAssetStruct,
      inputAssetB: AztecTypes.AztecAssetStruct,
      outputAssetA: AztecTypes.AztecAssetStruct,
      outputAssetB: AztecTypes.AztecAssetStruct,
      totalInputValue: BigNumberish,
      interactionNonce: BigNumberish,
      auxInputData: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    failed(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    processAsyncDefiInteraction(
      interactionNonce: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    receiveEthFromBridge(
      interactionNonce: BigNumberish,
      overrides?: PayableOverrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    setBridgeGasLimit(
      bridgeAddress: string,
      gasLimit: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;
  };
}
