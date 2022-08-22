import { ethers } from "ethers";
import ABIAPI from 'abiapi';
import { getProvider } from "base/provider";
import { isArray, isArrayLikeObject, isObject, isObjectLike } from 'lodash';
import getBaseUrl from 'base/url';

import ModuleABIs from '@polly-os/utils/js/ModuleABIs';


// NUMBER PARSER
function bigNumbersToNumber(value){

    if(value._isBigNumber){
        return value.toNumber();
    }
    else if(isArray(value)){
        return value.map(bigNumbersToNumber);
    }
    else if(isObject(value)){

        for(const key in value) {
            if (Object.hasOwnProperty.call(value, key)) {
                value[key] = bigNumbersToNumber(value[key])
            }
        }    
        return value;
    }

    return value;

}

function moduleParser(module){

    return {
        name: module[0],
        version: module[1],
        implementation: module[2],
        clonable: module[3]
    }
}


function parseReturnParam(param){

    return {
        name: param[0],
        _string: param[1],
        _int: param[2],
        _bool: param[3],
        _address: param[4]
    };
    
}

function parseConfig(config){
    return {
        name: config[0],
        params: config[1].map(parseReturnParam)
    }

}


export default async (req, res) => {
    
    const data = {};
    const {name, address, method, version, ...query} = req.query;

    const moduleABI = ModuleABIs[name];
    const abi = new ABIAPI(moduleABI);
    abi.supportedMethods = abi.getReadMethods();
    abi.cacheTTL = 60*60;

    abi.addParser('getConfigsForAddress', (configs) => configs.filter(config => config[0] !== '').map(parseConfig));
    abi.addGlobalParser(bigNumbersToNumber)
    abi.addParser('getModule', moduleParser)
    abi.addParser('getModules', (modules) => modules.filter(mod => mod[0] !== '').map(moduleParser))
    
    const module = await fetch(`${getBaseUrl()}/api/polly/getModule?name_=${name}&version_=${version ? version : 0}`).then(res => res.json()).then(res => res.result);

    if(abi.supportsMethod(method)){

        const provider = getProvider();

        const contract = new ethers.Contract(address, moduleABI, provider);
        
        try {
            data.result = await contract[method](...abi.methodParamsFromQuery(method, query));
            data.result = abi.parse(method, data.result);
        }
        catch(e){
            data.error = e.toString();
        }

    }
    else{
        data.error = 'Unsupported method';
    }

    const status = data.error ? 400 : 200;

    if(status == 200)
        res.setHeader(`Cache-Control`, `s-maxage=${abi.getMethodCacheTTL(method)}, stale-while-revalidate`)

    res.status(status).json(data);


}