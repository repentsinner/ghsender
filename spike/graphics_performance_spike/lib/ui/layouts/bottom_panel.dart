import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../themes/vscode_theme.dart';

/// Bottom Panel widget - tabbed interface for console, problems, output
class BottomPanel extends StatefulWidget {
  final VoidCallback onTogglePanel;

  const BottomPanel({
    super.key,
    required this.onTogglePanel,
  });

  @override
  State<BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<BottomPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: VSCodeTheme.panelTheme,
      child: Container(
        color: VSCodeTheme.panelBackground,
        child: Column(
          children: [
            // Panel header with tabs and close button
            Container(
              height: 35,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: VSCodeTheme.border),
                ),
              ),
              child: Row(
                children: [
                  // Tabs
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: const [
                        Tab(text: 'Console'),
                        Tab(text: 'Problems'),
                        Tab(text: 'Output'),
                      ],
                    ),
                  ),
                  
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: VSCodeTheme.secondaryText,
                    onPressed: widget.onTogglePanel,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              ),
            ),
            
            // Panel content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildConsoleTab(),
                  _buildProblemsTab(),
                  _buildOutputTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConsoleTab() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Console',
            style: GoogleFonts.inconsolata(
              color: VSCodeTheme.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VSCodeTheme.editorBackground,
                borderRadius: VSCodeTheme.containerRadius,
                border: Border.all(color: VSCodeTheme.border),
              ),
              child: SingleChildScrollView(
                child: Text(
                  'Console output will appear here...\nApplication logs and real-time information.',
                  style: GoogleFonts.inconsolata(
                    color: VSCodeTheme.secondaryText,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProblemsTab() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Problems',
            style: GoogleFonts.inconsolata(
              color: VSCodeTheme.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VSCodeTheme.editorBackground,
                borderRadius: VSCodeTheme.containerRadius,
                border: Border.all(color: VSCodeTheme.border),
              ),
              child: Text(
                'No problems detected.',
                style: GoogleFonts.inconsolata(
                  color: VSCodeTheme.success,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOutputTab() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Output',
            style: GoogleFonts.inconsolata(
              color: VSCodeTheme.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VSCodeTheme.editorBackground,
                borderRadius: VSCodeTheme.containerRadius,
                border: Border.all(color: VSCodeTheme.border),
              ),
              child: SingleChildScrollView(
                child: Text(
                  'Application output logs...\nDetailed renderer information and debug data.',
                  style: GoogleFonts.inconsolata(
                    color: VSCodeTheme.secondaryText,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}