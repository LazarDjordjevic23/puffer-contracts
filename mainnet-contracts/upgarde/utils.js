const fs = require('fs');
const path = require('path');
const branch = require('git-branch');

function getSavedContractAddresses() {
    let json
    let gitBranch = branch.sync()
    try {
        const filePath = `../deployments/${gitBranch}-contract-addresses.json`
        json = fs.readFileSync(path.join(__dirname, filePath))
    } catch (err) {
        json = '{}'
    }
    return JSON.parse(json)
}

function saveContractAddress(network, contract, address) {
    const addrs = getSavedContractAddresses()
    addrs[network] = addrs[network] || {}
    addrs[network][contract] = address
    let gitBranch = branch.sync()
    const filePath = `../deployments/${gitBranch}-contract-addresses.json`
    fs.writeFileSync(path.join(__dirname, filePath), JSON.stringify(addrs, null, '    '))
}

function getSavedContractProxies() {
    let json
    let gitBranch = branch.sync()
    try {
        const filePath = `../deployments/${gitBranch}-contract-proxies.json`
        json = fs.readFileSync(path.join(__dirname, filePath))
    } catch (err) {
        json = '{}'
    }
    return JSON.parse(json)
}

function saveContractProxies(network, contract, address) {
    const addrs = getSavedContractProxies()
    addrs[network] = addrs[network] || {}
    addrs[network][contract] = address
    let gitBranch = branch.sync()
    const filePath = `../deployments/${gitBranch}-contract-proxies.json`
    fs.writeFileSync(path.join(__dirname, filePath), JSON.stringify(addrs, null, '    '))
}


module.exports = {
    getSavedContractAddresses,
    saveContractAddress,
    getSavedContractProxies,
    saveContractProxies
}
