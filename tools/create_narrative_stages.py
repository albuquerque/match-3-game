#!/usr/bin/env python3
"""
Generate missing narrative stage files for main_story.json
Creates simple text-based narrative stages for all biblical stories
"""

import json
import os

# Base directory for narrative stages
STAGES_DIR = "data/narrative_stages"

# Narrative stage definitions with biblical content
STAGES = {
    "creation_day_3": {
        "name": "Day 3: Land and Plants",
        "text": "God said, 'Let the waters be gathered together,\nand let dry land appear.'\n\nAnd God saw that it was good.",
        "bg_color": "#2E5C3F",
        "text_color": "#FFFFFF"
    },
    "creation_day_4": {
        "name": "Day 4: Sun, Moon, and Stars",
        "text": "God created two great lights—\nthe greater light to rule the day,\nand the lesser light to rule the night.",
        "bg_color": "#1A1A3A",
        "text_color": "#FFD700"
    },
    "creation_day_5": {
        "name": "Day 5: Sea Creatures and Birds",
        "text": "God created the great sea creatures\nand every living thing that moves in the waters,\nand every winged bird.",
        "bg_color": "#0C4A6E",
        "text_color": "#FFFFFF"
    },
    "creation_day_6a": {
        "name": "Day 6: Animals",
        "text": "God made the beasts of the earth,\nthe livestock, and everything that creeps on the ground.",
        "bg_color": "#4A3C28",
        "text_color": "#FFFFFF"
    },
    "creation_day_6b": {
        "name": "Day 6: Humanity",
        "text": "God created mankind in His own image,\nmale and female He created them.\n\nAnd it was very good.",
        "bg_color": "#5C3A1F",
        "text_color": "#FFE4B5"
    },
    "creation_day_7": {
        "name": "Day 7: Rest",
        "text": "On the seventh day God finished His work,\nand He rested.\n\nGod blessed the seventh day and made it holy.",
        "bg_color": "#2C2C54",
        "text_color": "#E6E6FA"
    },
    "garden_of_eden": {
        "name": "The Garden of Eden",
        "text": "The Lord God planted a garden in Eden,\nand there He placed the man He had formed.\n\nA place of perfect peace.",
        "bg_color": "#1B5E20",
        "text_color": "#FFFFFF"
    },
    "the_fall": {
        "name": "The Fall",
        "text": "The serpent deceived them, and they ate the forbidden fruit.\n\nSin entered the world,\nand they were cast from the garden.",
        "bg_color": "#1A1A1A",
        "text_color": "#FF6B6B"
    },
    "cain_and_abel": {
        "name": "Cain and Abel",
        "text": "Abel's offering was accepted,\nbut Cain's was not.\n\nJealousy led to tragedy.",
        "bg_color": "#2C0E0E",
        "text_color": "#FFCCCC"
    },
    "noah_called": {
        "name": "Noah's Call",
        "text": "God saw the wickedness of mankind\nand decided to flood the earth.\n\nBut Noah found favor in God's eyes.",
        "bg_color": "#1E3A5F",
        "text_color": "#FFFFFF"
    },
    "the_flood": {
        "name": "The Great Flood",
        "text": "Rain fell for forty days and forty nights.\n\nThe waters covered the earth,\nbut the ark kept Noah and his family safe.",
        "bg_color": "#0D1B2A",
        "text_color": "#89CFF0"
    },
    "rainbow_covenant": {
        "name": "The Rainbow Covenant",
        "text": "God placed a rainbow in the sky\nas a sign of His promise:\n\n'Never again will I flood the earth.'",
        "bg_color": "#4A5568",
        "text_color": "#FFD700"
    },
    "tower_of_babel": {
        "name": "Tower of Babel",
        "text": "Mankind tried to build a tower to heaven.\n\nGod confused their language\nand scattered them across the earth.",
        "bg_color": "#8B4513",
        "text_color": "#FFE4B5"
    },
    "abraham_called": {
        "name": "Abram's Call",
        "text": "God called Abram to leave his homeland:\n\n'Go to the land I will show you,\nand I will make you a great nation.'",
        "bg_color": "#2C1810",
        "text_color": "#F4A460"
    },
    "three_visitors": {
        "name": "Three Visitors",
        "text": "Three mysterious visitors came to Abraham.\n\nThey promised that Sarah would bear a son,\ndespite her old age.",
        "bg_color": "#3A3A2A",
        "text_color": "#FFFACD"
    },
    "sodom_destroyed": {
        "name": "Sodom Destroyed",
        "text": "The cities of Sodom and Gomorrah were wicked.\n\nFire and brimstone rained down,\nbut Lot and his daughters escaped.",
        "bg_color": "#000000",
        "text_color": "#FF4500"
    },
    "isaac_born": {
        "name": "Isaac is Born",
        "text": "Sarah laughed when told she would have a son.\n\nBut God kept His promise,\nand Isaac was born.",
        "bg_color": "#FFE5B4",
        "text_color": "#2C1810"
    },
    "binding_of_isaac": {
        "name": "The Binding of Isaac",
        "text": "God tested Abraham:\n'Take your son Isaac and offer him as a sacrifice.'\n\nAbraham obeyed, but God provided a ram instead.",
        "bg_color": "#4A3728",
        "text_color": "#FFD700"
    },
    "rebekah_at_well": {
        "name": "Rebekah at the Well",
        "text": "Abraham's servant prayed for a sign,\nand Rebekah appeared at the well.\n\nShe would become Isaac's wife.",
        "bg_color": "#6B8E23",
        "text_color": "#FFFFFF"
    },
    "birthright_sold": {
        "name": "The Birthright Sold",
        "text": "Esau sold his birthright to Jacob\nfor a bowl of stew.\n\nA moment's hunger cost him everything.",
        "bg_color": "#8B4513",
        "text_color": "#FFA07A"
    },
    "stolen_blessing": {
        "name": "The Stolen Blessing",
        "text": "Jacob disguised himself as Esau\nand stole his father's blessing.\n\nDeception brought blessing, but also exile.",
        "bg_color": "#2F2F2F",
        "text_color": "#FFE4C4"
    },
    "jacobs_ladder": {
        "name": "Jacob's Ladder",
        "text": "Jacob dreamed of a ladder reaching to heaven,\nwith angels ascending and descending.\n\nGod renewed His promise there.",
        "bg_color": "#1A1A3A",
        "text_color": "#FFFFFF"
    },
    "rachel_at_well": {
        "name": "Rachel at the Well",
        "text": "Jacob met Rachel at a well\nand fell in love immediately.\n\nHe would work fourteen years to marry her.",
        "bg_color": "#4682B4",
        "text_color": "#FFFFFF"
    },
    "twelve_tribes": {
        "name": "The Twelve Sons",
        "text": "Jacob had twelve sons,\nwho would become the twelve tribes of Israel.\n\nGod's promise was multiplying.",
        "bg_color": "#2C5F2D",
        "text_color": "#FFD700"
    },
    "jacob_wrestles": {
        "name": "Wrestling with God",
        "text": "Jacob wrestled with a mysterious man all night.\n\nHe received a new name: Israel,\n'one who struggles with God.'",
        "bg_color": "#1C1C3C",
        "text_color": "#E0E0FF"
    },
    "josephs_dreams": {
        "name": "Joseph's Dreams",
        "text": "Joseph dreamed that his brothers' sheaves\nbowed down to his.\n\nHis brothers hated him for it.",
        "bg_color": "#191970",
        "text_color": "#FFD700"
    },
    "joseph_sold": {
        "name": "Joseph Sold",
        "text": "Joseph's brothers sold him to traders\nand told their father he was dead.\n\nBetrayal by blood.",
        "bg_color": "#2C1810",
        "text_color": "#CD853F"
    },
    "joseph_imprisoned": {
        "name": "Joseph Imprisoned",
        "text": "Falsely accused, Joseph was thrown into prison.\n\nYet even there, the Lord was with him.",
        "bg_color": "#1A1A1A",
        "text_color": "#A0A0A0"
    },
    "prison_dreams": {
        "name": "Dreams in Prison",
        "text": "Joseph interpreted the dreams\nof Pharaoh's cupbearer and baker.\n\nEverything happened as he said.",
        "bg_color": "#2F4F4F",
        "text_color": "#F0E68C"
    },
    "pharaohs_dreams": {
        "name": "Pharaoh's Dreams",
        "text": "Pharaoh dreamed of seven fat cows\nand seven lean cows.\n\nJoseph alone could interpret it.",
        "bg_color": "#FFD700",
        "text_color": "#8B4513"
    },
    "joseph_exalted": {
        "name": "Joseph Exalted",
        "text": "Pharaoh made Joseph second-in-command\nover all of Egypt.\n\nFrom prisoner to prince in one day.",
        "bg_color": "#4A148C",
        "text_color": "#FFD700"
    },
    "brothers_arrive_egypt": {
        "name": "Brothers Come to Egypt",
        "text": "Famine drove Joseph's brothers to Egypt,\nseeking food.\n\nThey didn't recognize the brother they sold.",
        "bg_color": "#8B7355",
        "text_color": "#FFFFFF"
    },
    "silver_cup": {
        "name": "The Silver Cup",
        "text": "Joseph tested his brothers\nby hiding his cup in Benjamin's sack.\n\nWould they abandon him as they did Joseph?",
        "bg_color": "#2F4F4F",
        "text_color": "#C0C0C0"
    },
    "joseph_revealed": {
        "name": "Joseph Reveals Himself",
        "text": "'I am Joseph, your brother,\nwhom you sold into Egypt.'\n\nTears and forgiveness followed.",
        "bg_color": "#4682B4",
        "text_color": "#FFFFFF"
    },
    "israel_to_egypt": {
        "name": "Israel Goes to Egypt",
        "text": "Jacob and his entire family\nmoved to Egypt.\n\nSeventy souls, who would become a great nation.",
        "bg_color": "#CD853F",
        "text_color": "#000000"
    },
    "jacobs_blessings": {
        "name": "Jacob Blesses His Sons",
        "text": "Before he died, Jacob blessed each of his sons,\nprophesying their futures.\n\nJudah would bring forth kings.",
        "bg_color": "#4B0082",
        "text_color": "#FFD700"
    },
    "joseph_final_days": {
        "name": "Joseph's Final Days",
        "text": "Joseph lived to see his great-grandchildren.\n\nBefore dying, he made them promise:\n'Carry my bones from this place.'",
        "bg_color": "#2F2F2F",
        "text_color": "#E0E0E0"
    },
    "israel_multiplies": {
        "name": "Israel Multiplies",
        "text": "The Israelites were fruitful\nand multiplied greatly.\n\nThe land of Egypt was filled with them.",
        "bg_color": "#2E5C3F",
        "text_color": "#FFFFFF"
    },
    "new_pharaoh": {
        "name": "A New Pharaoh",
        "text": "A new king arose over Egypt,\nwho did not know Joseph.\n\nHe feared the Israelites' numbers.",
        "bg_color": "#8B0000",
        "text_color": "#FFD700"
    },
    "slavery_begins": {
        "name": "Slavery Begins",
        "text": "The Egyptians made the Israelites slaves,\nforcing them to make bricks and build cities.\n\nTheir cry rose up to God.",
        "bg_color": "#654321",
        "text_color": "#D2691E"
    },
    "midwives_courage": {
        "name": "The Brave Midwives",
        "text": "Pharaoh ordered all Hebrew boys killed,\nbut the midwives feared God\nand let them live.",
        "bg_color": "#4A5568",
        "text_color": "#FFE4E1"
    },
    "moses_in_basket": {
        "name": "Moses in the Basket",
        "text": "A mother placed her baby in a basket\nand set him in the Nile.\n\nPharaoh's daughter found him.",
        "bg_color": "#4682B4",
        "text_color": "#FFFFFF"
    },
    "moses_adopted": {
        "name": "Moses Adopted",
        "text": "Pharaoh's daughter raised Moses\nas her own son.\n\nA Hebrew prince in Egypt's palace.",
        "bg_color": "#FFD700",
        "text_color": "#8B4513"
    },
    "moses_flees": {
        "name": "Moses Flees",
        "text": "Moses killed an Egyptian taskmaster\nand fled to Midian.\n\nHe became a shepherd in the wilderness.",
        "bg_color": "#8B7355",
        "text_color": "#FFFFFF"
    },
    "burning_bush": {
        "name": "The Burning Bush",
        "text": "God spoke to Moses from a bush\nthat burned but was not consumed:\n\n'I will send you to Pharaoh.'",
        "bg_color": "#000000",
        "text_color": "#FF4500"
    },
    "let_my_people_go": {
        "name": "Let My People Go",
        "text": "Moses and Aaron stood before Pharaoh:\n\n'Thus says the Lord:\nLet My people go!'",
        "bg_color": "#8B0000",
        "text_color": "#FFFFFF"
    },
    "plague_blood": {
        "name": "First Plague: Blood",
        "text": "Aaron struck the Nile with his staff,\nand all the water turned to blood.\n\nBut Pharaoh's heart was hardened.",
        "bg_color": "#8B0000",
        "text_color": "#FFFFFF"
    },
    "plague_frogs": {
        "name": "Second Plague: Frogs",
        "text": "Frogs covered the land of Egypt,\nin houses, bedrooms, and ovens.\n\nStill Pharaoh refused.",
        "bg_color": "#228B22",
        "text_color": "#FFFFFF"
    },
    "plagues_continue": {
        "name": "Plagues Continue",
        "text": "Gnats, flies, and pestilence\nstruck the land of Egypt.\n\nYet Pharaoh would not relent.",
        "bg_color": "#2F2F2F",
        "text_color": "#FFD700"
    },
    "plagues_livestock_boils": {
        "name": "Livestock and Boils",
        "text": "The livestock died,\nand painful boils broke out on all Egyptians.\n\nThe plagues grew worse.",
        "bg_color": "#4B0000",
        "text_color": "#FFA07A"
    },
    "plague_hail": {
        "name": "Seventh Plague: Hail",
        "text": "Hail and fire rained from the sky,\ndestroying crops and killing cattle.\n\nEgypt had never seen such devastation.",
        "bg_color": "#000080",
        "text_color": "#FFFFFF"
    },
    "plague_locusts": {
        "name": "Eighth Plague: Locusts",
        "text": "Locusts covered the ground\nuntil the land was black.\n\nThey devoured everything the hail had left.",
        "bg_color": "#1A1A1A",
        "text_color": "#90EE90"
    },
    "plague_darkness": {
        "name": "Ninth Plague: Darkness",
        "text": "Darkness covered Egypt for three days,\nso thick it could be felt.\n\nBut Israel had light in their dwellings.",
        "bg_color": "#000000",
        "text_color": "#FFFFFF"
    },
    "passover_night": {
        "name": "The Passover",
        "text": "The final plague came at midnight.\n\nBut the angel passed over every house\nmarked with lamb's blood.",
        "bg_color": "#8B0000",
        "text_color": "#FFFFFF"
    },
    "exodus_begins": {
        "name": "The Exodus Begins",
        "text": "Pharaoh finally let them go.\n\nIsrael left Egypt with great wealth,\na pillar of cloud leading them.",
        "bg_color": "#4682B4",
        "text_color": "#FFFFFF"
    },
    "red_sea_crossing": {
        "name": "Crossing the Red Sea",
        "text": "God parted the Red Sea,\nand Israel walked through on dry ground.\n\nThe waters covered Pharaoh's army.",
        "bg_color": "#0C4A6E",
        "text_color": "#FFD700"
    }
}

def create_narrative_stage(stage_id, data):
    """Create a narrative stage JSON file"""
    stage_data = {
        "id": stage_id,
        "name": data["name"],
        "description": data["name"],
        "anchor": "fullscreen",
        "background_color": data["bg_color"],
        "text_color": data["text_color"],
        "states": [
            {
                "name": "main",
                "text": data["text"],
                "duration": 3.0
            }
        ],
        "transitions": [
            {
                "from": "",
                "to": "main",
                "event": "stage_loaded"
            }
        ]
    }

    filepath = os.path.join(STAGES_DIR, f"{stage_id}.json")

    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(stage_data, f, indent=2, ensure_ascii=False)

    print(f"✓ Created {stage_id}.json")

def main():
    """Generate all missing narrative stages"""
    print("Creating missing narrative stage files...")
    print(f"Output directory: {STAGES_DIR}")
    print()

    # Ensure directory exists
    os.makedirs(STAGES_DIR, exist_ok=True)

    created_count = 0
    skipped_count = 0

    for stage_id, data in STAGES.items():
        filepath = os.path.join(STAGES_DIR, f"{stage_id}.json")

        if os.path.exists(filepath):
            print(f"⊘ Skipped {stage_id}.json (already exists)")
            skipped_count += 1
        else:
            create_narrative_stage(stage_id, data)
            created_count += 1

    print()
    print(f"Summary: Created {created_count} files, skipped {skipped_count} existing files")
    print("Done!")

if __name__ == "__main__":
    main()
