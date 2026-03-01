model FestivalAuction

global {
    int nb_guests <- 6;
    int nb_auctioneers <- 2;
    // 定义商品类别
    list<string> item_genres <- ["T-Shirt", "CD", "Poster", "Cap"];
    
    // --- 新增：颜色映射配置 ---
    map<string, rgb> genre_colors <- [
        "T-Shirt":: #red, 
        "CD":: #blue, 
        "Poster":: #green, 
        "Cap":: #yellow
    ];
    
    init {
        write "-----------------------------------------------------";
        write "--- SYSTEM INITIALIZATION: GUEST PROFILE ANALYSIS ---";
        write "-----------------------------------------------------";

        create guest number: nb_guests {
            location <- {rnd(100), rnd(100)};
            
            // 随机生成该 Guest 对不同商品的兴趣和心理价位
            loop genre over: item_genres {
                // 70% 的几率对某商品感兴趣
                if (flip(0.7)) {
                    float min_val <- 0.0;
					float max_val <- 0.0;
                    if (genre = "Poster") { min_val <- 3.0; max_val <- 20.0; } 
                    else if (genre = "CD") { min_val <- 10.0; max_val <- 50.0; } 
                    else if (genre = "Cap") { min_val <- 100.0; max_val <- 400.0; } 
                    else if (genre = "T-Shirt") { min_val <- 200.0; max_val <- 800.0; } 
                    else { min_val <- 10.0; max_val <- 100.0; }

                    valuations[genre] <- rnd(min_val, max_val); 
                }
            }
            
            // 打印 Guest 详细信息 (保留原样)
            write "GUEST [" + name + "] Total Budget: " + int(budget);
            loop genre over: item_genres {
                if (genre in valuations.keys) {
                    write "\tItem: " + genre + " -> Interested (Psychological Val: " + int(valuations[genre]) + ")";
                } else {
                    write "\tItem: " + genre + " -> Not Interested";
                }
            }
            write " "; 
        }
        
        create auctioneer number: nb_auctioneers {
            location <- {rnd(100), rnd(100)};
        }
    }
}

species guest skills: [fipa, moving] {
    float budget <- rnd(500.0, 2000.0);
    map<string, float> valuations; 
    
    // 状态变量
    bool in_auction <- false;
    string current_auction_id;
    string current_item_type;
    
    // 1. Receive Invitation (Join the Room)
    reflex receive_cfp when: !empty(cfps) {
        loop cfpMsg over: cfps {
            list msg_content <- cfpMsg.contents;
            string auction_id <- string(msg_content[1]);
            string item_genre <- string(msg_content[3]);
            
            // Decision: Do I like this genre? (Price is unknown yet)
            if ((item_genre in valuations.keys) and !in_auction) {
                write name + ": Joining room for " + item_genre;
                do propose message: cfpMsg contents: ['interested', true, 'auction_id', auction_id];
                
                // 更新状态 (这里删除了 color <- #green，改为状态控制)
                in_auction <- true;
                current_auction_id <- auction_id;
                current_item_type <- item_genre;
            } else {
                do refuse message: cfpMsg contents: ['interested', false];
            }
        }
    }
    
    // 2. Receive Price Proposal (The actual bidding)
    reflex receive_propose when: !empty(proposes) {
        loop proposeMsg over: proposes {
            list msg_content <- proposeMsg.contents;
            float current_price <- float(msg_content[1]);
            string auction_id <- string(msg_content[3]);
            
            if (auction_id != current_auction_id) { continue; }
            
            float my_valuation <- valuations[current_item_type];
            
            // Logic: Buy if Price <= Valuation AND Price <= Budget
            if (current_price <= my_valuation and current_price <= budget) {
                write name + ": !!! BUYING at " + current_price + " (Val: " + my_valuation + ") !!!";
                do accept_proposal message: proposeMsg contents: ['accept', true, 'bid', current_price];
            } else {
                // Dutch Auction silence implies rejection usually, but we act polite
                do reject_proposal message: proposeMsg contents: ['accept', false];
            }
        }
    }
    
    // 3. Receive Results
    reflex receive_inform when: !empty(informs) {
        loop informMsg over: informs {
            list msg_content <- informMsg.contents;
            string result <- string(msg_content[1]);
            
            if (result = 'won') {
                float final_price <- float(msg_content[3]);
                write name + ": WON " + current_item_type + " for " + final_price;
                budget <- budget - final_price;
                // 这里移除了 color <- #gold
                remove key: current_item_type from: valuations; 
            } else if (result = 'lost') {
                 // 这里移除了 color <- #red
            } else if (result = 'cancelled') {
                 // 这里移除了 color <- #gray
            }
            
            // 重置状态，颜色会自动变回灰色
            in_auction <- false;
            current_auction_id <- nil;
            current_item_type <- nil;
        }
    }
    
    // --- 修改后的显示逻辑 ---
    aspect base { 
        rgb display_color <- #grey; // 默认灰色
        string label_text <- name;
        
        // 如果在拍卖中，改为对应种类颜色
        if (in_auction and (current_item_type in genre_colors.keys)) {
            display_color <- genre_colors[current_item_type];
            label_text <- label_text + "\n-> " + current_auction_id; // 显示参与的拍卖ID
        }
        
        draw circle(2) color: display_color; 
        draw label_text color: #black size: 3 at: location + {0, 3.5} anchor: #center;
    }
}

species auctioneer skills: [fipa] {
    bool auction_active <- false;
    string auction_id;
    string item_genre;
    
    float starting_price;
    float current_price;
    float minimum_price;
    float price_decrement;
    
    // Timer control
    int price_update_interval <- 1;
    int timer <- 0;
    
    // Logic control
    bool first_round <- true; 
    
    list<guest> participants;
    guest winner;
    
    // Step 1: Invite participants
    reflex start_auction when: !auction_active and flip(0.1) {
        auction_active <- true;
        auction_id <- name + "_" + cycle;
        item_genre <- one_of(item_genres);
        
        // 不同商品不同定价策略
        switch item_genre {
            match "CD" { starting_price <- 50.0; price_decrement <- 5.0; minimum_price <- 10.0; }
            match "Poster" { starting_price <- 20.0; price_decrement <- 2.0; minimum_price <- 3.0; }
            match "Cap" { starting_price <- 400.0; price_decrement <- 30.0; minimum_price <- 100.0; }
            match "T-Shirt" { starting_price <- 800.0; price_decrement <- 150.0; minimum_price <- 200.0; }
        }
        
        current_price <- starting_price;
        participants <- [];
        winner <- nil;
        timer <- 0;
        first_round <- true; 
        
        write "--------------------------------------------------";
        write "--- NEW AUCTION: " + item_genre + " ---";
        write "--- Strategy: Start Price " + starting_price + " | Drop Rate " + price_decrement + " | Min " + minimum_price + " ---";
        
        do start_conversation to: list(guest) protocol: 'fipa-contract-net' performative: 'cfp' 
            contents: ['auction_id', auction_id, 'genre', item_genre];
            
        // 这里移除了 color <- #orange
    }
    
    // Handle joins
    reflex receive_joins when: auction_active and !empty(proposes) {
        loop proposeMsg over: proposes {
            list msg_content <- proposeMsg.contents;
            if (length(msg_content) >= 2 and msg_content[0] = 'interested') {
                guest participant <- guest(proposeMsg.sender);
                if !(participant in participants) {
                    participants << participant;
                }
            }
        }
    }
    
    // Clean Refuses
    reflex clean_mailbox when: !empty(refuses) or !empty(reject_proposals) {
         loop msg over: refuses + reject_proposals { list dummy <- msg.contents; }
    }

    // Step 2: Conduct the Auction Loop
    reflex conduct_auction when: auction_active and !empty(participants) {
        timer <- timer + 1;
        
        if (timer >= price_update_interval) {
            
            // 2a. Check if anyone bought
            if (!empty(accept_proposals)) {
                message winning_msg <- first(accept_proposals);
                winner <- guest(winning_msg.sender);
                
                write ">>> SOLD: " + item_genre + " to " + winner.name + " for " + current_price;
                
                do inform message: winning_msg contents: ['result', 'won', 'final_price', current_price, 'auction_id', auction_id];
                
                list<guest> losers <- participants - winner;
                loop loser over: losers {
                    do start_conversation to: [loser] protocol: 'fipa-contract-net' performative: 'inform' contents: ['result', 'lost', 'auction_id', auction_id];
                }
                do end_auction;
                return; 
            }
            
            // 2b. Prepare next price
            if (first_round) {
                write name + ": First call -> " + current_price;
                first_round <- false; 
            } else {
                current_price <- current_price - price_decrement;
                write name + ": Dropping Price -> " + current_price;
            }
            
            // 2c. Check Minimum Price
            if (current_price < minimum_price) {
                write "--- CANCELLED: Reserve not met (Current: " + current_price + " < Min: " + minimum_price + ") ---";
                loop participant over: participants {
                    do start_conversation to: [participant] protocol: 'fipa-contract-net' performative: 'inform' contents: ['result', 'cancelled', 'auction_id', auction_id];
                }
                do end_auction;
            } else {
                // 2d. Broadcast Price
                loop participant over: participants {
                    do start_conversation to: [participant] protocol: 'fipa-contract-net' performative: 'propose'
                        contents: ['price', current_price, 'auction_id', auction_id];
                }
            }
            
            timer <- 0;
        }
    }
    
    action end_auction {
        auction_active <- false;
        participants <- [];
        winner <- nil;
        // 这里移除了 color <- #red
        // 也不需要重置 item_genre，因为 aspect 会检查 auction_active
    }
    
    // --- 修改后的显示逻辑 ---
    aspect base {
        rgb display_color <- #grey; // 默认灰色
        string label_text <- name;
        
        if (auction_active) {
            // 激活时根据商品变色
            if (item_genre in genre_colors.keys) {
                 display_color <- genre_colors[item_genre];
            }
            // 显示商品名
            label_text <- label_text + "\nSelling: " + item_genre;
            // 也可以选择显示价格: + "\n$" + current_price;
        }
        
        draw square(5) color: display_color;
        draw label_text color: #black size: 3 at: location + {0, -6} anchor: #center;
    }
}

experiment FestivalAuction type: gui {
    output {
        display main_display {
            // 简单的图例
            graphics "Legend" {
                draw "Red: T-Shirt | Blue: CD | Green: Poster | Yellow: Cap" at: {70, -3} color: #black font: font("Helvetica", 10, #bold);
            }
            graphics "Legend" {
//                draw "Genre Legend:" at: {5, 5} color: #black font: font("Helvetica", 14, #bold);
                int y_pos <- 5;
                loop g over: genre_colors.keys {
                    draw square(2) at: {5, y_pos} color: genre_colors[g];
                    draw g at: {8, y_pos + 1} color: #black font: font("Helvetica", 12, #plain);
                    y_pos <- y_pos + 5;
                }
            }
            species guest aspect: base;
            species auctioneer aspect: base;
        }
        monitor "Active Auctions" value: length(auctioneer where each.auction_active);
    }
}