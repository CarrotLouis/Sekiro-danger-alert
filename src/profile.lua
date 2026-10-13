return {
 steam_build='25480438',
 exe_sha256='F5FEE03DCFDB2E553A4752C283590950AC13316B376D8196AA556FF0400D5F06',
 game_sha256='2E2C3B7C2500646DADD5F2B4C6E0504DBB7E7896139F64CDDC0D1813C718F51E',
 avatar_resource='4d1c334d294dfa97',
 crusher_resource='905809a4c28d8a45',
 pins={{module='exe',rva=5587676,bytes=table.concat({
"\072\139\065\040"
}),label='animation resource'},{module='exe',rva=5587728,bytes=table.concat({
"\072\139\070\080\076\139\012\003"
}),label='animation active layers'},{module='exe',rva=5587753,bytes=table.concat({
"\069\139\068\011\004\076\003\193"
}),label='animation group offsets'},{module='exe',rva=2873456,bytes=table.concat({
"\072\141\065\096\195"
}),label='unit scene graph'},{module='exe',rva=6235350,bytes=table.concat({
"\072\139\044\002"
}),label='resource slot'},{module='exe',rva=1475261,bytes=table.concat({
"\199\001\051\131\042\217"
}),label='material object'},{module='exe',rva=2090495,bytes=table.concat({
"\068\139\066\016"
}),label='scene graph node count'},{module='exe',rva=2090504,bytes=table.concat({
"\072\139\082\064"
}),label='scene graph node names'},{module='exe',rva=3201408,bytes=table.concat({
"\243\015\016\065\052\195"
}),label='camera field of view'},{module='game',rva=19879363,bytes=table.concat({
"\076\139\013\150\127\023\002"
}),label='camera manager global'},{module='game',rva=19374476,bytes=table.concat({
"\015\017\067\012"
}),label='camera cached right'},{module='game',rva=19374484,bytes=table.concat({
"\015\017\075\028"
}),label='camera cached forward'},{module='game',rva=19374492,bytes=table.concat({
"\015\017\067\044"
}),label='camera cached up'},{module='game',rva=19374507,bytes=table.concat({
"\015\017\075\060"
}),label='camera cached position'}},
 targeting_pins={{rva=7060989,bytes=table.concat({
"\072\139\029\044\175\198\002"
}),label='targeting manager'},{rva=7062525,bytes=table.concat({
"\139\139\064\001\000\000"
}),label='targeting count'},{rva=7061072,bytes=table.concat({
"\072\139\131\104\001\000\000"
}),label='targeting handles'},{rva=7061105,bytes=table.concat({
"\076\105\254\208\000\000\000"
}),label='targeting stride'},{rva=7061120,bytes=table.concat({
"\076\003\187\120\001\000\000"
}),label='targeting records'},{rva=7061094,bytes=table.concat({
"\072\139\131\128\001\000\000"
}),label='targeting network'},{rva=7061384,bytes=table.concat({
"\128\123\120\000"
}),label='AI has target'},{rva=7061469,bytes=table.concat({
"\139\067\024"
}),label='AI target entity'},{rva=7061463,bytes=table.concat({
"\246\067\096\001"
}),label='AI entity tracking flag'},{rva=7061472,bytes=table.concat({
"\065\137\007"
}),label='AI target copied to aiming'},{rva=7062482,bytes=table.concat({
"\137\012\059"
}),label='replicated target resolved to entity'},{rva=7062452,bytes=table.concat({
"\129\250\255\127\000\000"
}),label='invalid network target sentinel'},{rva=8669627,bytes=table.concat({
"\076\139\013\126\029\174\002"
}),label='behavior manager'},{rva=8669640,bytes=table.concat({
"\069\139\081\072"
}),label='behavior map capacity'},{rva=8669691,bytes=table.concat({
"\073\139\121\064"
}),label='behavior map keys'},{rva=8669745,bytes=table.concat({
"\073\139\065\088"
}),label='behavior handles'},{rva=8659711,bytes=table.concat({
"\072\105\250\248\001\000\000"
}),label='behavior stride'},{rva=8659726,bytes=table.concat({
"\073\003\123\096"
}),label='behavior records'},{rva=8664224,bytes=table.concat({
"\131\124\046\012\255"
}),label='pending behavior stage'},{rva=8664265,bytes=table.concat({
"\139\020\046"
}),label='behavior ID'}},
 targeting_resources={['843d18d4b5512b63']='big_walker_turret_cannon',['49674794a165eda8']='tank_turret_autocannons',['b8580cac32214fc0']='tank_turret_base',['8fb47dd28b398cf7']='tank_turret_heavycannon',['5d142c3a73ebc634']='tank_turret_rocketlauncher',['aeaef7a1851e6c9d']='turret_autocannons',['abdb2e2a0479d8ca']='turret_base',['cd28a27a79be53d5']='turret_command_bunker_hmg',['2cf3488c4845f8bd']='turret_heavycannon',['ff5cc825b9571052']='turret_mortar'},
 -- 1411/1412 have live capture support. Other branches are statically reviewed;
 -- exact move names / live coverage still need confirmation. Never use shared animation hashes alone.
 attack_states={[1411]=true,[1412]=true,[1413]=true,[1414]=true,[1415]=true,[1416]=true,
                [1417]=true,[1418]=true,[1419]=true,[1420]=true,[1421]=true,[1422]=true,[1424]=true},
 ignored_stomps={[1409]=true,[1410]=true,[1423]=true},
}
