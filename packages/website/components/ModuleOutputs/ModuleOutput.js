import Module from './Module.js';

export default function ModuleOutput(p){

    const {info, param} = p;

    return <div style={{marginBottom: '1em'}}>
        
        <h4>{info.name}</h4>
        <small>type: {info.type}</small>
        {(info.type) === 'module' && <Module {...p}/>}

        </div>

}