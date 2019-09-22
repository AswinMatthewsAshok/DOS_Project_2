args = System.argv()
[numNodes, topology, algorithm] = args
actors = Gossip.Topologies.build_topology(topology,String.to_integer(numNodes),algorithm)
IO.puts(Gossip.Boss.manage(actors,0))
Gossip.Topologies.terminate_actors(actors)