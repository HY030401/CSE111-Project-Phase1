import psycopg2

DB_NAME = "postgres"
DB_USER = "postgres"
DB_PASSWORD = "yhz030401"
DB_HOST = "localhost"
DB_PORT = "5432"


def get_connection():
    """
    Create and return a new database connection.
    """
    conn = psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        host=DB_HOST,
        port=DB_PORT,
    )
    return conn




# Feature: Browse Products
def browse_products(conn):
    """
    Show all active products (is_active = TRUE).
    """
    try:
        cur = conn.cursor()
        query = """
            SELECT product_id, sku, name, unit_price, is_active
            FROM product
            WHERE is_active = TRUE
            ORDER BY product_id;
        """
        cur.execute(query)
        rows = cur.fetchall()

        print("\n=== Product List ===")
        print("{:<5} {:<10} {:<30} {:>10}".format("ID", "SKU", "Name", "Price"))
        print("-" * 60)
        for r in rows:
            product_id, sku, name, unit_price, is_active = r
            print("{:<5} {:<10} {:<30} {:>10.2f}".format(
                product_id, sku, name, float(unit_price)
            ))

        cur.close()
    except Exception as e:
        print("Error while browsing products:", e)





# Feature: Revenue-related (best-selling etc.)
def best_selling_products(conn):
    """
    Show best-selling products by quantity and sales.
    Admin-only (in Admin Menu).
    """
    try:
        cur = conn.cursor()
        query = """
            SELECT p.sku, p.name,
                   SUM(il.quantity) AS units,
                   SUM(il.line_total) AS sales
            FROM product p
            JOIN invoice_line il ON il.product_id = p.product_id
            GROUP BY p.sku, p.name
            ORDER BY units DESC;
        """
        cur.execute(query)
        rows = cur.fetchall()

        print("\n=== Best-selling Products ===")
        print("{:<10} {:<30} {:>8} {:>12}".format(
            "SKU", "Name", "Units", "Sales"))
        print("-" * 65)
        for sku, name, units, sales in rows:
            print("{:<10} {:<30} {:>8} {:>12.2f}".format(
                sku, name, int(units), float(sales)
            ))

        cur.close()
    except Exception as e:
        print("Error while getting best-selling products:", e)


def view_total_net_profit(conn):
    """
    Show revenue by country (gross sales from invoice_line),
    then show total net profit (sum of all payments including refunds).
    """
    try:
        cur = conn.cursor()

        # 1) Revenue by country (gross revenue, ignores refunds)
        query_revenue_by_country = """
            SELECT c.name AS country,
                   SUM(il.line_total) AS revenue
            FROM invoice i
            JOIN customer cu ON cu.customer_id = i.customer_id
            JOIN country c ON c.country_id = cu.country_id
            JOIN invoice_line il ON il.invoice_id = i.invoice_id
            GROUP BY c.name
            ORDER BY revenue DESC;
        """
        cur.execute(query_revenue_by_country)
        rows = cur.fetchall()

        print("\n=== Revenue by Country ===")
        print("{:<20} {:>12}".format("Country", "Revenue"))
        print("-" * 35)
        for country, revenue in rows:
            print("{:<20} {:>12.2f}".format(country, float(revenue)))

        # 2) Total net profit (all payments including refunds)
        cur.execute("SELECT COALESCE(SUM(amount), 0) FROM payment;")
        row = cur.fetchone()
        net_profit = float(row[0]) if row and row[0] is not None else 0.0

        print("\n=== Total Net Profit ===")
        print(f"Net profit: {net_profit:.2f}")

        cur.close()

    except Exception as e:
        print("Error while calculating revenue and net profit:", e)





# Feature: Place Order & Pay (Customer)
def list_customers_short(conn):
    """
    Print a short list of customers (id + name).
    """
    cur = conn.cursor()
    cur.execute("""
        SELECT customer_id, full_name
        FROM customer
        ORDER BY customer_id;
    """)
    rows = cur.fetchall()
    print("\n=== Customers ===")
    for cid, name in rows:
        print(f"{cid}: {name}")
    cur.close()


def place_order_and_pay(conn):
    """
    Create a new invoice + invoice_line(s) + payment.
    Simple version: mark invoice as PAID immediately.
    """
    try:
        cur = conn.cursor()

        # 1) choose customer
        list_customers_short(conn)
        customer_id_str = input("\nEnter customer ID: ").strip()
        try:
            customer_id = int(customer_id_str)
        except ValueError:
            print("Invalid customer ID.")
            return

        # 2) create invoice (status = PAID, currency = GBP)
        cur.execute("""
            INSERT INTO invoice (customer_id, invoice_date, status, currency, ship_to_country)
            VALUES (
                %s,
                NOW(),
                'PAID',
                'GBP',
                (SELECT c.name
                 FROM customer cu
                 JOIN country c ON c.country_id = cu.country_id
                 WHERE cu.customer_id = %s)
            )
            RETURNING invoice_id;
        """, (customer_id, customer_id))
        result = cur.fetchone()
        if not result:
            print("Failed to create invoice (customer not found?).")
            conn.rollback()
            return

        invoice_id = result[0]
        print(f"\nCreated invoice #{invoice_id}")

        # 3) add invoice_line
        total_amount = 0.0
        while True:
            print("\nAdd an order line (leave product ID empty to finish).")
            prod_str = input("Product ID: ").strip()
            if prod_str == "":
                break

            try:
                product_id = int(prod_str)
            except ValueError:
                print("Invalid product ID.")
                continue

            qty_str = input("Quantity: ").strip()
            try:
                quantity = int(qty_str)
                if quantity <= 0:
                    raise ValueError()
            except ValueError:
                print("Quantity must be a positive integer.")
                continue

            # look up product price
            cur.execute("""
                SELECT unit_price
                FROM product
                WHERE product_id = %s AND is_active = TRUE;
            """, (product_id,))
            row = cur.fetchone()
            if not row:
                print("Product not found or not active.")
                continue

            unit_price = float(row[0])

            # insert invoice_line
            cur.execute("""
                INSERT INTO invoice_line (invoice_id, product_id, quantity, unit_price)
                VALUES (%s, %s, %s, %s);
            """, (invoice_id, product_id, quantity, unit_price))

            line_total = quantity * unit_price
            total_amount += line_total
            print(f"Added line: product {product_id}, qty {quantity}, line total {line_total:.2f}.")

        if total_amount == 0.0:
            print("No order lines added, cancel invoice.")
            cur.execute("DELETE FROM invoice WHERE invoice_id = %s;", (invoice_id,))
            conn.commit()
            return

        print(f"\nOrder subtotal: {total_amount:.2f}")

        # 4) payment method
        method = input("Payment method (default CARD): ").strip().upper()
        if method == "":
            method = "CARD"

        # 5) insert payment
        cur.execute("""
            INSERT INTO payment (invoice_id, method, amount, paid_at)
            VALUES (%s, %s, %s, NOW());
        """, (invoice_id, method, total_amount))

        conn.commit()
        print(f"Order placed and paid successfully. Invoice #{invoice_id}, amount {total_amount:.2f}.")

    except Exception as e:
        conn.rollback()
        print("Error while placing order & payment:", e)





# Feature: Process Refund (Customer)
def process_refund(conn):
    """
    Record a refund for an invoice by inserting a negative payment.
    """
    try:
        cur = conn.cursor()

        inv_str = input("Enter invoice ID to refund: ").strip()
        try:
            invoice_id = int(inv_str)
        except ValueError:
            print("Invalid invoice ID.")
            return

        # show billed and paid so far
        cur.execute("""
            SELECT COALESCE(SUM(il.line_total), 0) AS billed
            FROM invoice_line il
            WHERE il.invoice_id = %s;
        """, (invoice_id,))
        billed = float(cur.fetchone()[0])

        cur.execute("""
            SELECT COALESCE(SUM(amount), 0) AS paid
            FROM payment
            WHERE invoice_id = %s;
        """, (invoice_id,))
        paid = float(cur.fetchone()[0])

        print(f"\nInvoice #{invoice_id}: billed = {billed:.2f}, paid so far = {paid:.2f}")

        amt_str = input("Refund amount: ").strip()
        try:
            refund_amount = float(amt_str)
            if refund_amount <= 0:
                raise ValueError()
        except ValueError:
            print("Refund amount must be a positive number.")
            return

        if refund_amount > paid:
            print("Warning: refund is greater than total payments, but will continue anyway.")

        # insert negative payment
        cur.execute("""
            INSERT INTO payment (invoice_id, method, amount, paid_at, external_ref)
            VALUES (%s, 'REFUND', %s, NOW(), NULL);
        """, (invoice_id, -refund_amount))

        conn.commit()
        print(f"Refund of {refund_amount:.2f} recorded for invoice #{invoice_id}.")

    except Exception as e:
        conn.rollback()
        print("Error while processing refund:", e)




# Admin: View Invoices and Details
def view_invoices_and_details(conn):
    """
    Admin function:
    1) List all invoices with: invoice_id, customer name, Y/N refunded.
    2) Ask to choose one invoice id.
    3) Show invoice details: customer, date, items (name + qty + price + line_total), and payments (method + amount).
    """
    try:
        cur = conn.cursor()

        # 1) List all invoices with refund flag
        query_list = """
            SELECT i.invoice_id,
                   cu.full_name,
                   CASE
                     WHEN EXISTS (
                        SELECT 1
                        FROM payment p
                        WHERE p.invoice_id = i.invoice_id
                          AND p.amount < 0
                     ) THEN 'Y'
                     ELSE 'N'
                   END AS has_refund
            FROM invoice i
            JOIN customer cu ON cu.customer_id = i.customer_id
            ORDER BY i.invoice_id;
        """
        cur.execute(query_list)
        rows = cur.fetchall()

        print("\n=== All Invoices ===")
        print("{:<5} {:<25} {:<10}".format("ID", "Customer", "Refund?"))
        print("-" * 45)
        for inv_id, full_name, has_refund in rows:
            print("{:<5} {:<25} {:<10}".format(inv_id, full_name, has_refund))

        # 2) Ask for invoice id
        inv_str = input("\nEnter invoice ID to view details (blank to return): ").strip()
        if inv_str == "":
            cur.close()
            return

        try:
            invoice_id = int(inv_str)
        except ValueError:
            print("Invalid invoice ID.")
            cur.close()
            return

        # 3) Header: invoice + customer
        query_header = """
            SELECT i.invoice_id,
                   cu.full_name,
                   i.invoice_date,
                   i.status,
                   i.ship_to_country
            FROM invoice i
            JOIN customer cu ON cu.customer_id = i.customer_id
            WHERE i.invoice_id = %s;
        """
        cur.execute(query_header, (invoice_id,))
        header = cur.fetchone()

        if not header:
            print("Invoice not found.")
            cur.close()
            return

        inv_id, full_name, inv_date, status, ship_country = header

        print("\n=== Invoice Details ===")
        print(f"Invoice ID   : {inv_id}")
        print(f"Customer     : {full_name}")
        print(f"Date         : {inv_date}")
        print(f"Status       : {status}")
        print(f"Ship To      : {ship_country}")

        # 4) Items
        query_items = """
            SELECT p.name,
                   il.quantity,
                   il.unit_price,
                   il.line_total
            FROM invoice_line il
            JOIN product p ON p.product_id = il.product_id
            WHERE il.invoice_id = %s;
        """
        cur.execute(query_items, (invoice_id,))
        items = cur.fetchall()

        print("\n--- Items ---")
        print("{:<30} {:>8} {:>10} {:>12}".format("Product", "Qty", "Price", "Total"))
        print("-" * 65)
        for name, qty, price, total in items:
            print("{:<30} {:>8} {:>10.2f} {:>12.2f}".format(
                name, qty, float(price), float(total)
            ))

        # 5) Payments
        query_pay = """
            SELECT method, amount, paid_at
            FROM payment
            WHERE invoice_id = %s
            ORDER BY paid_at;
        """
        cur.execute(query_pay, (invoice_id,))
        pays = cur.fetchall()

        print("\n--- Payments / Refunds ---")
        if not pays:
            print("No payment records.")
        else:
            for method, amount, paid_at in pays:
                print(f"{method:8} {amount:10.2f} at {paid_at}")

        cur.close()

    except Exception as e:
        print("Error while viewing invoices and details:", e)





# Menus
def customer_menu(conn):
    """
    Customer-facing menu: browse products, place orders, refunds.
    """
    while True:
        print("\n=== Customer Menu ===")
        print("1. Browse Products")
        print("2. Place Order & Pay")
        print("3. Process Refund")
        print("0. Back")

        choice = input("Enter choice: ").strip()

        if choice == "1":
            browse_products(conn)
        elif choice == "2":
            place_order_and_pay(conn)
        elif choice == "3":
            process_refund(conn)
        elif choice == "0":
            break
        else:
            print("Invalid choice, please try again.")


def admin_menu(conn):
    """
    Admin menu: view invoices, net profit, best-selling products.
    """
    while True:
        print("\n=== Admin Menu ===")
        print("1. View All Invoices and Details")
        print("2. View sales rankings and total net profit")
        print("3. View Best-selling Products")
        print("0. Back")

        choice = input("Enter choice: ").strip()

        if choice == "1":
            view_invoices_and_details(conn)
        elif choice == "2":
            view_total_net_profit(conn)
        elif choice == "3":
            best_selling_products(conn)
        elif choice == "0":
            break
        else:
            print("Invalid choice, please try again.")


def main():
    """Top-level main menu: choose role."""
    try:
        conn = get_connection()
    except Exception as e:
        print("Failed to connect to database:", e)
        return

    try:
        while True:
            print("\n=== Online Retail System ===")
            print("1. Customer Menu")
            print("2. Admin Menu")
            print("0. Exit")

            choice = input("Enter choice: ").strip()

            if choice == "1":
                customer_menu(conn)
            elif choice == "2":
                admin_menu(conn)
            elif choice == "0":
                print("Bye!")
                break
            else:
                print("Invalid choice, please try again.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
