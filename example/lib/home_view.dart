import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';
import 'package:example/inapp_view.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f2f5), // WhatsApp Web background color
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xff00a884), // WhatsApp primary green
        foregroundColor: Colors.white,
        title: const Text('WhatsApp Bot Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Obx(() => Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: controller.connected.value
                            ? Colors.greenAccent
                            : (controller.connecting.value
                                ? Colors.orangeAccent
                                : Colors.redAccent),
                        boxShadow: [
                          if (controller.connected.value ||
                              controller.connecting.value)
                            BoxShadow(
                              color: (controller.connected.value
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent)
                                  .withValues(alpha: 0.5),
                              blurRadius: 5,
                              spreadRadius: 2,
                            )
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      controller.connected.value
                          ? "Online (${controller.formatedDuration})"
                          : (controller.connecting.value
                              ? "Connecting..."
                              : "Offline"),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),
        ],
      ),
      body: Row(
        children: [
          // Main Panel
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(24.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildConnectionSection(),
                        const SizedBox(height: 24),
                        const MiddleFormView(),
                        const SizedBox(height: 24),
                        Obx(() => AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: controller.connected.value
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildActionsCard(),
                                        const SizedBox(height: 16),
                                        _buildAdvancedFeaturesCard(),
                                        const SizedBox(height: 24),
                                        _buildEventsSection(),
                                      ],
                                    )
                                  : _buildDisconnectedPlaceholder(),
                            )),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Side Console Panel
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff111b21), // Dark WhatsApp sidebar color
                border: Border(left: BorderSide(color: Colors.grey.shade800)),
              ),
              child: Column(
                children: [
                  _buildConsoleHeader(),
                  Expanded(child: _buildLogListView()),
                  _buildInAppPreview(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xff202c33),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.terminal, color: Colors.greenAccent, size: 20),
              SizedBox(width: 8),
              Text(
                "SYSTEM CONSOLE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                onPressed: () {
                  if (controller.logs.isNotEmpty) {
                    Clipboard.setData(
                        ClipboardData(text: controller.logs.join("\n")));
                    Get.snackbar("Success", "Logs copied to clipboard",
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.white,
                        colorText: Colors.black);
                  }
                },
                tooltip: "Copy Logs",
              ),
              IconButton(
                icon:
                    const Icon(Icons.delete_sweep, color: Colors.red, size: 18),
                onPressed: () => controller.logs.clear(),
                tooltip: "Clear Logs",
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Session Control",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSessionAction(
                      icon: Icons.rocket_launch,
                      label: "Instant Connect",
                      desc: "Start headless browser",
                      onTap: () => controller.initConnection(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSessionAction(
                      icon: Icons.open_in_browser,
                      label: "Visual Browser",
                      desc: "Interactive session",
                      onTap: () => controller.inApp.value = true,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildSmallAction(
                      Icons.refresh, "Reload", () => controller.client?.wpClient.reload()),
                  const SizedBox(width: 8),
                  _buildSmallAction(Icons.camera_alt, "Snapshot", _showScreenshot),
                  const SizedBox(width: 8),
                  _buildSmallAction(Icons.power_settings_new, "Disconnect", controller.disconnect,
                      isDestructive: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionAction({
    required IconData icon,
    required String label,
    required String desc,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSmallAction(IconData icon, String label, VoidCallback? onTap,
      {bool isDestructive = false}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDestructive ? Colors.red : Colors.grey.shade700,
        side: BorderSide(
            color: isDestructive ? Colors.red.withValues(alpha: 0.3) : Colors.grey.shade300),
      ),
    );
  }

  void _showScreenshot() async {
    final bytes = await controller.client?.wpClient.takeScreenshot();
    if (bytes != null) {
      Get.dialog(Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text("Browser Snapshot"),
                elevation: 0,
                actions: [
                  IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.close))
                ],
              ),
              Image.memory(bytes),
            ],
          ),
        ),
      ));
    }
  }

  Widget _buildDisconnectedPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(64),
      child: Column(
        children: [
          Icon(Icons.query_stats, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 24),
          const Text(
            "Ready to deploy your bot?",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Connect to a session to start sending messages and listening to events.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          Obx(() => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  "SELECTED WPP VERSION: ${controller.wppVersion.value}",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.1,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, size: 20, color: Colors.orange),
              SizedBox(width: 8),
              Text("Quick Actions",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          Form(
            key: controller.formKey,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  icon: Icons.send,
                  label: "Send Text",
                  onPressed: controller.sendMessage,
                  color: Colors.blue,
                ),
                _buildActionButton(
                  icon: Icons.smart_button,
                  label: "Buttons",
                  onPressed: controller.sendButtonMessage,
                  color: Colors.purple,
                ),
                _buildActionButton(
                  icon: Icons.image,
                  label: "Image",
                  onPressed: () =>
                      controller.pickFileAndSend(WhatsappFileType.image),
                  color: Colors.green,
                ),
                _buildActionButton(
                  icon: Icons.description,
                  label: "Document",
                  onPressed: () =>
                      controller.pickFileAndSend(WhatsappFileType.document),
                  color: Colors.orange,
                ),
              ],
            ),
          ),
          const Divider(height: 40),
          Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.group, size: 16),
                label: const Text("Get Groups"),
                onPressed: () => controller.getAllGroups(),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.chat_bubble, size: 16),
                label: const Text("Get Chats"),
                onPressed: () => controller.getChats(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFeaturesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, size: 20, color: Colors.amber),
              SizedBox(width: 8),
              Text("Advanced Features",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionButton(
                icon: Icons.edit_note,
                label: "Edit Last Msg",
                onPressed: controller.editLastMessage,
                color: Colors.teal,
              ),
              _buildActionButton(
                icon: Icons.push_pin,
                label: "Pin Last Msg",
                onPressed: controller.pinLastMessage,
                color: Colors.blueGrey,
              ),
              _buildActionButton(
                icon: Icons.history_edu,
                label: "Post Status",
                onPressed: controller.postStatus,
                color: const Color(0xff075E54),
              ),
              _buildActionButton(
                icon: Icons.label,
                label: "List Labels",
                onPressed: controller.listLabels,
                color: Colors.indigo,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Live Event Stream",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildEventsCard(),
      ],
    );
  }

  Widget _buildEventsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stream, size: 20, color: Colors.blueAccent),
              const SizedBox(width: 8),
              const Text("State Tracking",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Obx(() => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      controller.connectionEvent.value?.name.toUpperCase() ??
                          "IDLE",
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 20),
          Obx(() {
            final msg = controller.messageEvents.value;
            return _buildEventTile(
              icon: Icons.message,
              color: Colors.blue,
              title: "Last Message Received",
              content: msg == null
                  ? "Listening for incoming messages..."
                  : "${msg.from}: ${msg.type == 'chat' ? msg.body : '[${msg.type}]'}",
              trailing: msg != null
                  ? Text(
                      "${DateTime.now().hour}:${DateTime.now().minute}",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    )
                  : null,
            );
          }),
          const SizedBox(height: 12),
          Obx(() {
            final call = controller.callEvents.value;
            return _buildEventTile(
              icon: Icons.call,
              color: Colors.green,
              title: "Last Call Detected",
              content: call == null
                  ? "Monitoring call sessions..."
                  : "Call from ${call.sender}",
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEventTile({
    required IconData icon,
    required Color color,
    required String title,
    required String content,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold)),
                Text(content,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildInAppPreview() {
    return Obx(() => controller.inApp.value
        ? Container(
            height: 300,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: InappViewPage(onReturn: (inappController) {
              controller.initConnection(
                  inAppBrowser: true, controller: inappController);
            }),
          )
        : const SizedBox());
  }

  Widget _buildLogListView() {
    return Obx(() => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.logs.length,
          reverse: true,
          itemBuilder: (context, index) {
            final log = controller.logs[controller.logs.length - 1 - index];
            bool isError = log.toLowerCase().contains("error") ||
                log.toLowerCase().contains("exception");
            bool isSuccess = log.toLowerCase().contains("success") ||
                log.toLowerCase().contains("connected");

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "> ",
                    style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                  ),
                  Expanded(
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: isError
                            ? Colors.redAccent
                            : (isSuccess ? Colors.greenAccent : Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ));
  }
}

class MiddleFormView extends GetView<HomeController> {
  const MiddleFormView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, size: 20, color: Color(0xff00a884)),
              SizedBox(width: 8),
              Text("Configuration & Targeting",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          Obx(() => DropdownButtonFormField<String>(
                initialValue: controller.wppVersion.value,
                decoration: InputDecoration(
                  labelText: "WPP Version (wa-js)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon:
                      const Icon(Icons.history, color: Color(0xff00a884)),
                ),
                items: controller.availableVersions
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (val) => controller.wppVersion.value = val!,
              )),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller.phoneNumber,
            validator: (value) => (value?.isEmpty ?? true)
                ? "Enter phone number with country code"
                : null,
            decoration: InputDecoration(
              labelText: "Recipient Phone Number",
              hintText: "e.g., 1234567890",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon: const Icon(Icons.phone, color: Color(0xff00a884)),
              helperText: "Format: [CountryCode][Number]",
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller.message,
            maxLines: 2,
            validator: (value) {
              if (value?.isEmpty ?? true) return "Please type a message";
              if (!controller.connected.value) {
                return "Connect with WhatsApp first";
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: "Message Content",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon:
                  const Icon(Icons.text_fields, color: Color(0xff00a884)),
            ),
          ),
        ],
      ),
    );
  }
}
