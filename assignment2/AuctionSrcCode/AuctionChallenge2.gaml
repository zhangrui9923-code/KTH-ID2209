model AuctionChallenge2


global {
    int nb_guests <- 20;
    int nb_stores <- 6;
    int nb_auctioneers <- 6;
    int environment_size <- 100;
    
    point info_center_location <- {environment_size/2, environment_size/2};
    
    // Use "Sealed" uniformly to match chart labels and avoid Key errors
    list<string> auction_types <- ["Dutch", "English", "Sealed"]; 
    list<string> item_genres <- ["Clothes", "CDs", "Books", "Toys", "Art"];
    
    // Statistical Data Maps
    map<string, float> auctioneer_total_revenue <- ["Dutch"::0.0, "English"::0.0, "Sealed"::0.0];
    map<string, float> buyer_total_value <- ["Dutch"::0.0, "English"::0.0, "Sealed"::0.0];
    map<string, int> auction_count <- ["Dutch"::0, "English"::0, "Sealed"::0];
    map<string, int> successful_auctions <- ["Dutch"::0, "English"::0, "Sealed"::0];

    // --- Global Update Actions ---
    action register_revenue(string type, float amount) {
        if (type in auctioneer_total_revenue.keys) {
            auctioneer_total_revenue[type] <- auctioneer_total_revenue[type] + amount;
            successful_auctions[type] <- successful_auctions[type] + 1;
            write ">>> [Global Stats] Auction Success! Type: " + type + " Amount: " + amount + " (Total: " + auctioneer_total_revenue[type] + ")";
        }
    }

    action register_buyer_value(string type, float amount) {
        if (type in buyer_total_value.keys) {
            buyer_total_value[type] <- buyer_total_value[type] + amount;
        }
    }

    init {
        create InformationCenter number: 1 { location <- info_center_location; }
        
        create Store number: nb_stores {
            location <- {rnd(environment_size), rnd(environment_size)};
            store_type <- flip(0.5) ? "FOOD" : "WATER";
        }
        
        create Guest number: nb_guests {
            location <- {rnd(environment_size), rnd(environment_size)};
            hunger <- rnd(80.0, 100.0); // Initial state is fuller
            thirst <- rnd(80.0, 100.0);
            is_bad <- flip(0.1);
            has_memory <- flip(0.5);
            money <- rnd(200.0, 800.0); // Richer, easier to make a deal
            
            // Ensure everyone is interested in at least one item
            add one_of(item_genres) to: interests;
            if (flip(0.5)) { add one_of(item_genres) to: interests; }
        }
        
        create SecurityGuard number: 1 { location <- info_center_location + {5, 5}; }
        
        create Auctioneer number: nb_auctioneers {
            location <- {rnd(10.0, environment_size - 10.0), rnd(10.0, environment_size - 10.0)};
            auction_type <- one_of(auction_types);
            item_genre <- one_of(item_genres);
            item_market_value <- rnd(50.0, 200.0);
            
            // Initialize price parameters
            if (auction_type = "Dutch") {
                starting_price <- item_market_value * 2.0;
                min_price <- item_market_value * 0.2;
                price_decrement <- (starting_price - min_price) / 10.0; // Price drops faster
            } else if (auction_type = "English") {
                starting_price <- item_market_value * 0.3;
                min_increment <- item_market_value * 0.1;
            } else {
                starting_price <- item_market_value;
            }
            current_price <- starting_price;
            
            // Stagger start times to avoid congestion
            start_cycle_offset <- rnd(10, 40);
        }
    }
}

// ==================== Guest ====================
species Guest skills: [moving, fipa] {
    float hunger <- 100.0 min: 0.0 max: 100.0;
    float thirst <- 100.0 min: 0.0 max: 100.0;
    // Lower threshold so they are more willing to join auctions than eat
    float hunger_threshold <- 20.0; 
    float thirst_threshold <- 20.0;
    
    string state <- "idle" among: ["idle", "seeking_info", "going_to_store", "at_store", "in_auction"];
    point target_location <- nil;
    Store target_store <- nil;
    bool is_bad <- false;
    bool reported <- false;
    bool has_memory <- true;
    list<Store> memory <- [];
    point last_location <- location;
    
    // Auction related
    float money <- 500.0;
    list<string> interests <- [];
    agent current_auction <- nil;
    float auction_market_value <- 0.0;  // Save the market value of the current auction
    
    // --- Core Fix: Robust Message Parsing Helper Actions ---
    // Extract string value from message content list [key, val, key, val]
    string get_string_from_content(list content, string key_name) {
        loop i from: 0 to: length(content) - 1 step: 2 {
            if (string(content[i]) = key_name) {
                return string(content[i+1]);
            }
        }
        return "";
    }
    
    // Extract float value from message content list
    float get_float_from_content(list content, string key_name) {
        loop i from: 0 to: length(content) - 1 step: 2 {
            if (string(content[i]) = key_name) {
                return float(content[i+1]);
            }
        }
        return -1.0;
    }

    reflex decrease_needs when: state = "idle" {
        // Slow down hunger rate to give more time for auctions
        hunger <- hunger - rnd(0.05, 0.1); 
        thirst <- thirst - rnd(0.05, 0.1);
        do wander speed: 1.0;
    }
    
    reflex check_needs when: state = "idle" {
        if (hunger < hunger_threshold or thirst < thirst_threshold) {
            // Only leave when very hungry
            state <- "seeking_info";
            target_location <- info_center_location;
        }
    }
    
    // ... (Standard movement and store logic omitted, kept as is, simplified here) ...
    reflex move_to_target when: target_location != nil and state != "in_auction" {
        do goto target: target_location speed: 1.5;
        if (location distance_to target_location < 2.0) {
            if (state = "seeking_info") {
                ask InformationCenter closest_to location {
                    string type <- myself.hunger < myself.thirst ? "FOOD" : "WATER";
                    myself.target_store <- self.find_nearest_store(myself.location, type);
                    if (myself.target_store != nil) {
                        myself.target_location <- myself.target_store.location;
                        myself.state <- "going_to_store";
                    }
                }
            } else if (state = "going_to_store") {
                state <- "at_store";
            }
        }
    }
    
    reflex eat_drink when: state = "at_store" {
        hunger <- 100.0; thirst <- 100.0;
        state <- "idle"; target_location <- nil;
    }
    
    // ==================== Auction Logic (Using Helper Parsing) ====================
    
    // 1. Receive CFP (Invitation)
    reflex listen_to_cfps when: state != "in_auction" and !empty(cfps) {
        loop msg over: cfps {
            list c <- list(msg.contents);
            string genre <- get_string_from_content(c, "genre");
            string auc_type <- get_string_from_content(c, "auction_type");
            float market_val <- get_float_from_content(c, "market_value");
            
            // If interested and has money (relaxed conditions)
            if ((interests contains genre) and money > 50.0) {
                current_auction <- msg.sender;
                auction_market_value <- market_val;  // Save market value
                state <- "in_auction"; // Lock state
                
                do start_conversation with: [
                    to: [msg.sender], protocol: "fipa-contract-net", performative: "propose",
                    contents: ["interested", true]
                ];
                write name + " joins " + auc_type + " (" + genre + ")";
                // Joining one is enough, break loop
                break; 
            }
        }
    }
    
    // 2. Receive Propose (Dutch quote or SealedBid request or English bid result)
    reflex handle_proposes when: state = "in_auction" and !empty(proposes) {
        loop msg over: proposes {
            if (msg.sender = current_auction) {
                list c <- list(msg.contents);
                
                // Dutch Logic
                float d_price <- get_float_from_content(c, "current_price");
                if (d_price > 0) {
                    if (d_price <= money * 0.9) {
                        do start_conversation with: [to: [current_auction], protocol: "fipa-contract-net", performative: "accept_proposal", contents: ["bid", d_price]];
                        write name + " accepts Dutch price: " + d_price;
                    }
                    return;
                }
                
                // English Logic (Response to my bid usually, but here implies outbid or new round)
                // English is handled mostly via INFORMS in this model
                
                // Sealed Logic (Request to submit)
                string action_req <- get_string_from_content(c, "action");
                if (action_req = "submit_bid") {
                    float market_val <- get_float_from_content(c, "market_value");
                    float my_bid <- rnd(market_val * 0.5, min(money, market_val * 1.2));
                    do start_conversation with: [to: [current_auction], protocol: "fipa-contract-net", performative: "propose", contents: ["sealed_bid", my_bid]];
                    write name + " submits sealed bid: " + my_bid;
                }
            }
        }
    }
    
    // 3. Receive Inform (English update or Result notification)
    reflex handle_informs when: state = "in_auction" and !empty(informs) {
        loop msg over: informs {
            if (msg.sender = current_auction) {
                list c <- list(msg.contents);
                
                // Check if auction ended/cancelled
                string status <- get_string_from_content(c, "status");
                agent winner <- agent(c[1]); // Assume winner is at the second position, or use parsing
                
                // If message contains "winner" key (as sent in Auctioneer)
                // Simplified handling: if status=ended or cancelled, reset state
                if (status = "ended" or status = "cancelled") {
                    state <- "idle";
                    current_auction <- nil;
                    
                    // Check if self won
                    loop i from: 0 to: length(c) - 1 step: 2 {
                        if (string(c[i]) = "winner" and agent(c[i+1]) = self) {
                            float price <- get_float_from_content(c, "final_price");
                            string a_type <- get_string_from_content(c, "auction_type");
                            money <- money - price;
                            
                            // Correctly calculate buyer surplus = market value - actual payment
                            float buyer_gain <- auction_market_value - price;
                            ask world { do register_buyer_value(a_type, buyer_gain); }
                            
                            write name + " won auction! Cost: " + price + " (Market Val: " + auction_market_value + ", Surplus: " + buyer_gain + ")";
                            
                            // Reset market value
                            auction_market_value <- 0.0;
                        }
                    }
                    return;
                }
                
                // English Auction Update
                float highest <- get_float_from_content(c, "current_highest_bid");
                float inc <- get_float_from_content(c, "min_increment");
                
                if (highest > 0) {
                    float next_bid <- highest + inc;
                    if (next_bid < money and flip(0.6)) {
                        do start_conversation with: [to: [current_auction], protocol: "fipa-contract-net", performative: "propose", contents: ["bid", next_bid]];
                        write name + " English bids up to: " + next_bid;
                    }
                }
            }
        }
    }
    
    // 4. Receive Reject (English bid rejected/invalid)
    reflex handle_rejects when: state = "in_auction" and !empty(reject_proposals) {
        // Only this bid failed, no need to exit auction state
    }
    
    aspect default {
        draw circle(1.5) color: (state="in_auction") ? #gold : (state="idle" ? #gray : #blue);
    }
}

// ==================== Auctioneer ====================
species Auctioneer skills: [fipa] {
    string auction_type;
    string item_genre;
    float item_market_value;
    float starting_price;
    float current_price;
    float min_price;
    float price_decrement;
    float min_increment;
    
    int start_cycle_offset; // Random offset
    
    string state <- "preparing";
    int auction_round <- 0;
    list<agent> participants <- [];
    agent winner <- nil;
    float final_price <- 0.0;
    
    float highest_bid <- 0.0;
    agent highest_bidder <- nil;
    int no_bid_rounds <- 0;
    map<agent, float> sealed_bids <- [];

    // State Machine Logic
    reflex fsm {
        // 1. Preparation Phase: Attempt every 30 cycles, or at start (cycle = offset)
        if (state = "preparing") {
            if (cycle = start_cycle_offset or (cycle > start_cycle_offset and (cycle - start_cycle_offset) mod 30 = 0)) {
                state <- "announcing";
                participants <- [];
                winner <- nil;
                final_price <- 0.0;
                highest_bid <- 0.0;
                highest_bidder <- nil;
                sealed_bids <- [];
                
                // Reset prices
                current_price <- starting_price;
                if (auction_type = "English") { highest_bid <- starting_price; }
                
                write ">>> [NEW AUCTION] " + name + " starts " + auction_type + " for " + item_genre;
                
                do start_conversation with: [
                    to: list(Guest), protocol: "fipa-contract-net", performative: "cfp",
                    contents: ["auction_type", auction_type, "genre", item_genre, "starting_price", starting_price, "market_value", item_market_value]
                ];
            }
        }
        
        // 2. Participant Collection Phase
        else if (state = "announcing") {
            loop msg over: proposes {
                if !(participants contains msg.sender) { add msg.sender to: participants; }
            }
            
            // Wait 2 cycles to collect responses
            if (cycle mod 2 = 0) {
                if (length(participants) > 0) {
                    state <- "auctioning";
                    write name + ": " + length(participants) + " participants joined";
                    
                    // Sealed Bid special handling: send request
                    if (auction_type = "Sealed") {
                        do start_conversation with: [to: participants, protocol: "fipa-contract-net", performative: "propose", contents: ["action", "submit_bid", "market_value", item_market_value]];
                    }
                } else {
                    state <- "preparing"; // No participants, reset
                    write name + ": No participants, cancelled";
                }
            }
        }
        
        // 3. Auctioning Phase
        else if (state = "auctioning") {
            auction_round <- auction_round + 1;
            
            if (auction_type = "Dutch") {
                do run_dutch();
            } else if (auction_type = "English") {
                do run_english();
            } else if (auction_type = "Sealed") {
                do run_sealed();
            }
            
            if (auction_round > 20) { do cancel_auction; }
        }
    }
    
    action run_dutch {
        // Send current price
        do start_conversation with: [to: participants, protocol: "fipa-contract-net", performative: "propose", contents: ["current_price", current_price]];
        
        // Check if anyone accepted
        if (!empty(accept_proposals)) {
            winner <- accept_proposals[0].sender;
            final_price <- current_price;
            do end_auction;
        } else {
            current_price <- current_price - price_decrement;
            if (current_price < min_price) { do cancel_auction; }
        }
    }
    
    action run_english {
        // Broadcast highest bid
        do start_conversation with: [to: participants, protocol: "fipa-contract-net", performative: "inform", contents: ["current_highest_bid", highest_bid, "min_increment", min_increment]];
        
        bool new_bid <- false;
        loop msg over: proposes {
            list c <- list(msg.contents);
            // Simple parsing
            loop i from: 0 to: length(c)-1 step: 2 {
                if (string(c[i]) = "bid") {
                    float bid <- float(c[i+1]);
                    if (bid > highest_bid) {
                        highest_bid <- bid;
                        highest_bidder <- msg.sender;
                        new_bid <- true;
                    }
                }
            }
        }
        
        if (!new_bid) {
            no_bid_rounds <- no_bid_rounds + 1;
            if (no_bid_rounds >= 3 and highest_bidder != nil) {
                winner <- highest_bidder;
                final_price <- highest_bid;
                do end_auction;
            } else if (no_bid_rounds >= 3) {
                do cancel_auction;
            }
        } else {
            no_bid_rounds <- 0;
        }
    }
    
    action run_sealed {
        loop msg over: proposes {
             list c <- list(msg.contents);
             // Simple parsing
             loop i from: 0 to: length(c)-1 step: 2 {
                 if (string(c[i]) = "sealed_bid") {
                     sealed_bids[msg.sender] <- float(c[i+1]);
                 }
             }
        }
        
        if (length(sealed_bids) > 0 and auction_round > 3) {
            // Find highest
            float max_p <- 0.0;
            agent best_a <- nil;
            loop a over: sealed_bids.keys {
                if (sealed_bids[a] > max_p) { max_p <- sealed_bids[a]; best_a <- a; }
            }
            winner <- best_a;
            final_price <- max_p;
            do end_auction;
        }
    }
    
    action end_auction {
        state <- "preparing"; // Return to preparation state, wait for next round
        auction_round <- 0;
        
        // Global stats
        ask world { do register_revenue(myself.auction_type, myself.final_price); }
        
        // Notify everyone
        do start_conversation with: [
            to: participants, protocol: "fipa-contract-net", performative: "inform",
            contents: ["status", "ended", "winner", winner, "final_price", final_price, "auction_type", auction_type]
        ];
        write name + " Ended. Winner: " + winner + " Price: " + final_price;
    }
    
    action cancel_auction {
        state <- "preparing";
        auction_round <- 0;
        do start_conversation with: [to: participants, protocol: "fipa-contract-net", performative: "inform", contents: ["status", "cancelled"]];
        write name + " Cancelled.";
    }
    
    aspect default {
        draw square(4) color: (state="auctioning") ? #red : #green;
        draw string(auction_type) color: #black at: location + {0, -4};
    }
}

// ==================== Auxiliary Agents ====================
species Store {
    string store_type;
    aspect default { draw square(3) color: (store_type="FOOD"?#orange:#cyan); }
}
species InformationCenter {
    Store find_nearest_store(point p, string type) { return (Store where (each.store_type = type)) closest_to p; }
    aspect default { draw triangle(4) color: #green; }
}
species SecurityGuard skills: [moving] {
    aspect default { draw circle(1.5) color: #black; }
}

// ==================== Experiment ====================
experiment FestivalAuctionSimulation type: gui {
    output {
        display main_display {
            species Store; species InformationCenter; species Guest; species Auctioneer;
        }
        
        display stats_display {
            chart "Auctioneer Revenue (Cumulative)" type: histogram {
                data "Dutch" value: auctioneer_total_revenue["Dutch"] color: #purple;
                data "English" value: auctioneer_total_revenue["English"] color: #orange;
                data "Sealed" value: auctioneer_total_revenue["Sealed"] color: #pink;
            }
        }
        
        display buyer_display {
             chart "Buyer Value" type: histogram {
                data "Dutch" value: buyer_total_value["Dutch"] color: #purple;
                data "English" value: buyer_total_value["English"] color: #orange;
                data "Sealed" value: buyer_total_value["Sealed"] color: #pink;
            }
        }
    }
}