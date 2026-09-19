#include <atomic>
#include <csignal>
#include <cstring>
#include <iostream>
#include <mutex>
#include <optional>
#include <sstream>
#include <string>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <thread>
#include <unistd.h>
#include <vector>

#include <pqrs/karabiner/driverkit/virtual_hid_device_service.hpp>

namespace {
constexpr const char *kSocketPath = "/tmp/joypad-hid.sock";

std::atomic<bool> gExit{false};
std::atomic<bool> gKeyboardReady{false};
std::atomic<bool> gDriverConnected{false};
std::atomic<bool> gKarabinerConnected{false};
std::mutex gClientMutex;
pqrs::karabiner::driverkit::virtual_hid_device_service::client *gClient = nullptr;

uint16_t usage_for_key(const std::string &key) {
    using namespace pqrs::hid::usage::keyboard_or_keypad;
    if (key == "q") return type_safe::get(keyboard_q);
    if (key == "w") return type_safe::get(keyboard_w);
    if (key == "e") return type_safe::get(keyboard_e);
    if (key == "r") return type_safe::get(keyboard_r);
    if (key == "a") return type_safe::get(keyboard_a);
    if (key == "s") return type_safe::get(keyboard_s);
    if (key == "d") return type_safe::get(keyboard_d);
    if (key == "f") return type_safe::get(keyboard_f);
    if (key == "j") return type_safe::get(keyboard_j);
    if (key == "k") return type_safe::get(keyboard_k);
    if (key == "up") return type_safe::get(keyboard_up_arrow);
    if (key == "down") return type_safe::get(keyboard_down_arrow);
    if (key == "left") return type_safe::get(keyboard_left_arrow);
    if (key == "right") return type_safe::get(keyboard_right_arrow);
    return 0;
}

void post_keys(const std::vector<std::string> &keys) {
    std::lock_guard<std::mutex> lock(gClientMutex);
    if (gClient == nullptr) {
        return;
    }
    pqrs::karabiner::driverkit::virtual_hid_device_driver::hid_report::keyboard_input report;
    for (const auto &key : keys) {
        auto usage = usage_for_key(key);
        if (usage != 0) {
            report.keys.insert(usage);
        }
    }
    gClient->async_post_report(report);
}

std::string status_line() {
    std::ostringstream out;
    out << "OK keyboard=" << (gKeyboardReady.load() ? 1 : 0)
        << " driver=" << (gDriverConnected.load() ? 1 : 0)
        << " connected=" << (gKarabinerConnected.load() ? 1 : 0)
        << " uid=" << getuid() << "\n";
    return out.str();
}

std::string handle_line(const std::string &line) {
    if (line == "STATUS" || line.rfind("STATUS", 0) == 0) {
        return status_line();
    }
    if (line.rfind("KEYS", 0) == 0) {
        std::vector<std::string> keys;
        std::istringstream in(line.substr(4));
        std::string token;
        while (in >> token) {
            keys.push_back(token);
        }
        post_keys(keys);
        return status_line();
    }
    return "ERR unknown\n";
}

int listen_socket() {
    unlink(kSocketPath);
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        perror("socket");
        return -1;
    }
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    std::strncpy(addr.sun_path, kSocketPath, sizeof(addr.sun_path) - 1);
    if (bind(fd, reinterpret_cast<sockaddr *>(&addr), sizeof(addr)) < 0) {
        perror("bind");
        close(fd);
        return -1;
    }
    chmod(kSocketPath, 0666);
    if (listen(fd, 16) < 0) {
        perror("listen");
        close(fd);
        return -1;
    }
    return fd;
}

void serve_client(int client) {
    std::string pending;
    char buffer[512];
    while (!gExit.load()) {
        ssize_t n = recv(client, buffer, sizeof(buffer), 0);
        if (n <= 0) {
            break;
        }
        pending.append(buffer, static_cast<size_t>(n));
        size_t pos = 0;
        while ((pos = pending.find('\n')) != std::string::npos) {
            auto line = pending.substr(0, pos);
            if (!line.empty() && line.back() == '\r') {
                line.pop_back();
            }
            pending.erase(0, pos + 1);
            auto reply = handle_line(line);
            if (send(client, reply.data(), reply.size(), 0) < 0) {
                close(client);
                return;
            }
        }
    }
    close(client);
}

void start_karabiner() {
    pqrs::dispatcher::extra::initialize_shared_dispatcher();
    auto client = new pqrs::karabiner::driverkit::virtual_hid_device_service::client();
    {
        std::lock_guard<std::mutex> lock(gClientMutex);
        gClient = client;
    }

    client->connected.connect([client] {
        gKarabinerConnected = true;
        pqrs::karabiner::driverkit::virtual_hid_device_service::virtual_hid_keyboard_parameters parameters;
        parameters.set_country_code(pqrs::hid::country_code::us);
        client->async_virtual_hid_keyboard_initialize(parameters);
    });
    client->connect_failed.connect([](auto &&) {
        gKarabinerConnected = false;
        gKeyboardReady = false;
        gDriverConnected = false;
    });
    client->closed.connect([] {
        gKarabinerConnected = false;
        gKeyboardReady = false;
        gDriverConnected = false;
    });
    client->driver_connected.connect([](auto &&connected) {
        gDriverConnected = connected;
    });
    client->virtual_hid_keyboard_ready.connect([](auto &&ready) {
        gKeyboardReady = ready;
    });
    client->async_start();
}
} // namespace

int main() {
    std::signal(SIGINT, [](int) { gExit = true; });
    std::signal(SIGTERM, [](int) { gExit = true; });

    start_karabiner();

    int server = listen_socket();
    if (server < 0) {
        return 1;
    }

    while (!gExit.load()) {
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(server, &fds);
        timeval timeout{.tv_sec = 1, .tv_usec = 0};
        int ready = select(server + 1, &fds, nullptr, nullptr, &timeout);
        if (ready > 0 && FD_ISSET(server, &fds)) {
            int client = accept(server, nullptr, nullptr);
            if (client >= 0) {
                std::thread(serve_client, client).detach();
            }
        }
    }

    close(server);
    unlink(kSocketPath);
    _exit(0);
}
