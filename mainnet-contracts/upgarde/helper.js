const ethers = require("ethers");
const path = require('path');
const fs = require('fs');
const {estimateGasPrice} = require("./dynamicGasPrice");
require('dotenv').config();

const {
    saveContractAddress,
    saveContractProxies,
} = require('./utils');


// Function to get the RPC URL dynamically
const getRpcUrl = (networkName) => {
    const networks = require('./networks.json'); // Assuming networks are stored in a separate file
    return networks[networkName]?.url;
};

const globalConfig = require("./deployments/deploymentConfig.json");

/////////////////////// GLOBAL FUNCTIONS //////////////////////////////////

function fetchConfig(networkName){
    return {...getConfig(), ...globalConfig[networkName]}
}

function getConfig(){
    if(getNetworkEnv() === "develop") { return globalConfig.develop }
    else if (getNetworkEnv() === "staging") { return globalConfig.staging }
    else { return globalConfig.prod }
}

function getNetworkEnv(networkName) {
    let env;
    if(networkName.includes('mainnet') || networkName.includes('Mainnet')) env = 'prod';
    else if(networkName.includes('Staging') || networkName.includes('staging')) env = 'staging';
    else env = 'develop';
    return env;
}

/////////////////////// DEPLOY FUNCTIONS //////////////////////////////////

async function deployAndSaveImplementation(contractName, networkName){
    // Load the ABI from the JSON file
    const abiPath = path.join(__dirname, 'mainnet-contracts', 'out', contractName + '.sol', contractName + '.json');
    const contractJson = JSON.parse(fs.readFileSync(abiPath, 'utf-8'));
    const abi = contractJson.abi;

    let Contract = await ethers.ContractFactory(abi);
    let contract = await Contract.deploy({gasPrice: estimateGasPrice(networkName)});

    // Save contract implementation address
    console.log(contractName + " implementation address : ", contract.target + "\n")
    saveContractAddress(networkName, contractName, contract.target,false);

    return contract.target
}

function encodeData(types, values){
    let signature = "initialize("

    for(let i = 0; i < types.length; i++){
        signature += types[i];
        if(i !== types.length - 1) {signature += ","} else {signature += ")"}
    }
    console.log("Signature: ",signature)

    const methodId = (ethers.keccak256(ethers.toUtf8Bytes(signature))).substring(0,10);
    const abi = new ethers.AbiCoder(); // Get abi coder instance
    let data = methodId + abi.encode(types, values).substring(2); // Generate calldata
    console.log(`Calldata: ${data}` + "\n");

    return data;
}

async function deployAndSaveProxy(
    contractName,
    implementationAddress,
    proxyAdminAddress,
    types,
    values,
    networkName
){
    let data = encodeData(types, values)

    // Load the ABI from the JSON file
    const abiPath = path.join(
        __dirname,
        'mainnet-contracts',
        'out',
        'TransparentUpgradeableProxy.sol',
        'TransparentUpgradeableProxy.json'
    );

    const contractJson = JSON.parse(fs.readFileSync(abiPath, 'utf-8'));
    const abi = contractJson.abi;

    const proxyFactory = ethers.ContractFactory(abi);

    console.log("implementationAddress", implementationAddress)
    console.log("proxyAdminAddress", proxyAdminAddress)
    console.log("data", data)

    const proxy = await proxyFactory.deploy(
        implementationAddress,
        proxyAdminAddress,
        data,
        {gasPrice: estimateGasPrice(networkName)}
    );

    console.log(contractName + " proxy address : ", proxy.target + "\n")

    saveContractProxies(
        networkName,
        contractName,
        proxy.target,
        false
    );

    return proxy.target
}

module.exports = {
    deployAndSaveImplementation,
    deployAndSaveProxy,
    fetchConfig,
    getRpcUrl
}