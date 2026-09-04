{
  config,
  lib,
  pkgs,
  settings,
  ...
}:

let
  enabled = settings.xmrig.enable or false;

  # Linux requires CAP_SYS_RAWIO to open /dev/cpu/*/msr regardless of its file
  # permissions. Keep that capability away from the networked miner and make a
  # root-only helper save, apply, and restore the one Intel MSR used by RandomX.
  xmrigMsrControl = pkgs.writeShellScript "xmrig-msr-control" ''
    set -eu
    umask 077

    state_dir=/run/xmrig-msr
    register=0x1a4
    rdmsr=${lib.getExe' pkgs.msr-tools "rdmsr"}
    wrmsr=${lib.getExe' pkgs.msr-tools "wrmsr"}

    restore() {
      result=0
      for state_file in "$state_dir"/*.original; do
        [ -e "$state_file" ] || continue
        cpu_dir="''${state_file%.original}"
        cpu="''${cpu_dir##*/}"
        value="$(${pkgs.coreutils}/bin/tr -d '\n' < "$state_file")"
        if ! "$wrmsr" -p "$cpu" "$register" "$value"; then
          echo "Failed to restore MSR $register on CPU $cpu" >&2
          result=1
        fi
      done
      return "$result"
    }

    case "''${1:-}" in
      start)
        found=0
        for msr_device in /dev/cpu/[0-9]*/msr; do
          [ -e "$msr_device" ] || continue
          found=1
          cpu_dir="''${msr_device%/msr}"
          cpu="''${cpu_dir##*/}"
          original="$($rdmsr -p "$cpu" "$register")"
          printf '0x%s\n' "$original" > "$state_dir/$cpu.original"
        done

        if [ "$found" -eq 0 ]; then
          echo "No MSR devices found under /dev/cpu" >&2
          exit 1
        fi

        for state_file in "$state_dir"/*.original; do
          cpu_dir="''${state_file%.original}"
          cpu="''${cpu_dir##*/}"
          if ! "$wrmsr" -p "$cpu" "$register" 0xf; then
            echo "Failed to apply RandomX MSR optimization on CPU $cpu; restoring original values" >&2
            restore || true
            exit 1
          fi
        done
        ;;
      stop)
        restore
        ;;
      *)
        echo "Usage: $0 {start|stop}" >&2
        exit 2
        ;;
    esac
  '';
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

    # The helper below is the only process that accesses the MSR devices.
    hardware.cpu.x86.msr = {
      enable = true;
      settings.allow-writes = "on";
    };

    users.groups.xmrig.members = [ settings.username ];
    users.users.monero.extraGroups = [ "users" ];

    systemd.services.xmrig-msr = {
      description = "Apply and restore Intel RandomX MSR optimization";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "xmrig-msr";
        RuntimeDirectoryMode = "0700";
        ExecStart = "${xmrigMsrControl} start";
        ExecStop = "${xmrigMsrControl} stop";
      };
    };

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
