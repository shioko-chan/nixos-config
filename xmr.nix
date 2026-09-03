{
  config,
  lib,
  settings,
  ...
}:

let
  enabled = settings.xmrig.enable or false;
in
{
  config = lib.mkIf enabled {
    # monerod and XMRig both validate RandomX hashes. P2Pool's official Linux
    # setup recommends 3072 2 MiB pages when all three processes are present.
    boot.kernel.sysctl = {
      "vm.nr_hugepages" = 3072;
      # MAP_HUGETLB requires CAP_IPC_LOCK or membership in this group.
      "vm.hugetlb_shm_group" = config.ids.gids.users;
    };

    # XMRig itself runs as the desktop user. Only that user receives access to
    # the MSR devices needed to disable hardware prefetchers for RandomX.
    hardware.cpu.x86.msr = {
      enable = true;
      group = "xmrig";
      mode = "0660";
      settings.allow-writes = "on";
    };

    users.groups.xmrig.members = [ settings.username ];
    users.users.monero.extraGroups = [ "users" ];

    # P2Pool requires a fully synchronized Monero node with a ZMQ publisher.
    # Keep the pruned chain on the large data volume instead of the root disk.
    services.monero = {
      enable = true;
      dataDir = "${settings.paths.mountDir}/Monero/blockchain";
      prune = true;
      priorityNodes = [
        "p2pmd.xmrvsbeast.com:18080"
        "nodes.hashvault.pro:18080"
      ];
      rpc = {
        address = "127.0.0.1";
        port = 18081;
        restricted = false;
      };
      extraConfig = ''
        zmq-pub=tcp://127.0.0.1:18083
        out-peers=32
        in-peers=0
        no-igd=1
        enforce-dns-checkpointing=1
        enable-dns-blocklist=1
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${settings.paths.mountDir}/Monero 0750 monero monero -"
      "d ${settings.paths.mountDir}/Monero/blockchain 0700 monero monero -"
    ];

    security.pam.loginLimits = [
      {
        domain = "@xmrig";
        type = "-";
        item = "memlock";
        value = "unlimited";
      }
    ];
  };
}
