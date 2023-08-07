const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const WGhost = artifacts.require('WrappedGhost');

module.exports = async function (deployer) {
  const instance = await deployProxy(WGhost, { deployer, kind: 'uups'});
  console.log('Deployed', instance.address);
};