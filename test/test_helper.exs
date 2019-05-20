#-------------------------------------------------------------------------------
# Author: Keith Brings
# Copyright (C) 2018 Noizu Labs, Inc. All rights reserved.
#-------------------------------------------------------------------------------

require Logger
Logger.info """

  ----------------------------------
  Test Start
  ----------------------------------
"""
ExUnit.start()

alias Noizu.SimplePool.Support.TestPool
alias Noizu.SimplePool.Support.TestTwoPool
#alias Noizu.SimplePool.Support.TestThreePool
Application.ensure_all_started(:bypass)
Application.ensure_all_started(:semaphore)



#-----------------------------------------------
# Test Schema Setup
#-----------------------------------------------
Amnesia.start


#-------------------------
# V1 Core Tables
#-------------------------
if !Amnesia.Table.exists?(Noizu.SimplePool.Database.DispatchTable) do
  :ok = Noizu.SimplePool.Database.DispatchTable.create()
  :ok = Noizu.SimplePool.Database.Dispatch.MonitorTable.create()
  :ok = Noizu.SimplePool.Database.MonitoringFramework.SettingTable.create()
  :ok = Noizu.SimplePool.Database.MonitoringFramework.NodeTable.create()
  :ok = Noizu.SimplePool.Database.MonitoringFramework.ServiceTable.create()
  :ok = Noizu.SimplePool.Database.MonitoringFramework.Service.HintTable.create()

  :ok = Noizu.SimplePool.Database.MonitoringFramework.Node.EventTable.create()
  :ok = Noizu.SimplePool.Database.MonitoringFramework.Service.EventTable.create()
end


#-------------------------
# V2 Core Tables
#-------------------------
if !Amnesia.Table.exists?(Noizu.SimplePool.V2.Database.SettingTable) do
  :ok = Noizu.SimplePool.V2.Database.SettingTable.create()
  :ok = Noizu.SimplePool.V2.Database.ConfigurationTable.create()
  :ok = Noizu.SimplePool.V2.Database.NodeTable.create()
  :ok = Noizu.SimplePool.V2.Database.ServiceTable.create()
end

#---------------------
# Test Pool: Dispatch Tables
#---------------------
if !Amnesia.Table.exists?(Noizu.SimplePool.TestDatabase.TestV2Pool.DispatchTable) do
  :ok = Noizu.SimplePool.TestDatabase.TestV2Pool.DispatchTable.create()
end
if !Amnesia.Table.exists?(Noizu.SimplePool.TestDatabase.TestV2TwoPool.DispatchTable) do
  :ok = Noizu.SimplePool.TestDatabase.TestV2TwoPool.DispatchTable.create()
end
if !Amnesia.Table.exists?(Noizu.SimplePool.TestDatabase.TestV2ThreePool.DispatchTable) do
  :ok = Noizu.SimplePool.TestDatabase.TestV2ThreePool.DispatchTable.create()
end


:ok = Amnesia.Table.wait(Noizu.SimplePool.Database.tables(), 5_000)
:ok = Amnesia.Table.wait(Noizu.SimplePool.TestDatabase.tables(), 5_000)

true = Node.connect(:"second@127.0.0.1")
:rpc.call(:"second@127.0.0.1", Amnesia, :start, [])

spawn_second = if !Enum.member?(Amnesia.info(:db_nodes),:"second@127.0.0.1") do
    # conditional include to reduce the need to restart the remote server
    IO.puts "SPAWN SECOND == true"
    :mnesia.change_config(:extra_db_nodes, [:"second@127.0.0.1"])
    true
  else
    IO.puts "SPAWN SECOND == false"
    false
  end

#-----------------------------------------------
# Registry and Environment Manager Setup - Local
#-----------------------------------------------
context = Noizu.ElixirCore.CallingContext.system(%{})
Noizu.SimplePool.TestHelpers.setup_first()
:ok = Noizu.SimplePool.TestHelpers.unique_ref(:one)
      |> Noizu.SimplePool.TestHelpers.wait_hint_release(TestPool.Server, context)

if spawn_second do
  IO.puts "Provision Second Node for Test"
  {:pid, _second_pid} = :rpc.call(:"second@127.0.0.1", Noizu.SimplePool.TestHelpers, :setup_second, [])
else
  IO.puts "Checking second node state"
  case :rpc.call(:"second@127.0.0.1", Noizu.MonitoringFramework.EnvironmentPool.Server, :node_health_check!, [context, %{}]) do
    {:badrpc, _} -> {:pid, _second_pid} = :rpc.call(:"second@127.0.0.1", Noizu.SimplePool.TestHelpers, :setup_second, [])
    v -> IO.puts "Checking second node state #{inspect v}"
  end
end

:ok = Noizu.SimplePool.TestHelpers.unique_ref(:two)
      |> Noizu.SimplePool.TestHelpers.wait_hint_release(TestTwoPool.Server, context)
