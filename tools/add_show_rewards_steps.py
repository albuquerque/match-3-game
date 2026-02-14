#!/usr/bin/env python3
"""
Add show_rewards steps to experience flow after each level node.
This ensures the level transition/rewards screen appears after level completion.
"""

import json
import sys

def add_show_rewards_steps(flow_path: str):
    """Add show_rewards step after each level in the flow"""

    # Load the flow
    with open(flow_path, 'r') as f:
        data = json.load(f)

    flow = data.get('flow', [])
    new_flow = []

    for i, node in enumerate(flow):
        # Add the current node
        new_flow.append(node)

        # If this is a level node, add a show_rewards step after it
        if node.get('type') == 'level':
            level_id = node.get('id', '')
            # Extract level number from id (e.g., "level_01" -> 1)
            level_num = int(level_id.replace('level_', '').replace('level', ''))

            show_rewards_node = {
                "type": "show_rewards",
                "level_number": level_num,
                "completed": True
            }
            new_flow.append(show_rewards_node)
            print(f"Added show_rewards step after {level_id}")

    # Update the flow
    data['flow'] = new_flow

    # Write back
    with open(flow_path, 'w') as f:
        json.dump(data, f, indent=4)

    print(f"\n✅ Updated {flow_path}")
    print(f"   Original nodes: {len(flow)}")
    print(f"   New nodes: {len(new_flow)}")
    print(f"   Added {len(new_flow) - len(flow)} show_rewards steps")

if __name__ == '__main__':
    flow_path = 'data/experience_flows/main_story.json'
    if len(sys.argv) > 1:
        flow_path = sys.argv[1]

    add_show_rewards_steps(flow_path)
