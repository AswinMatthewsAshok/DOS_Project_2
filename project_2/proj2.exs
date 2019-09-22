args = System.argv()
[numNodes, topology, algorithm] = args
actors = Gossip.Topologies.build_topology(topology,String.to_integer(numNodes),algorithm)
states = Gossip.Topologies.multi_call(actors,{:set_and_get_state})
IO.puts(Gossip.Boss.manage(actors,states,0))