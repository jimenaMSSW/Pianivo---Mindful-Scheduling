from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0005_ownersubscription'),
    ]

    operations = [
        migrations.AddField(
            model_name='business',
            name='deposit_percentage',
            field=models.PositiveSmallIntegerField(default=0, help_text='Deposit percentage from 0 to 100.'),
        ),
        migrations.AddField(
            model_name='business',
            name='requires_deposit',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='payment',
            name='deposit_amount',
            field=models.PositiveIntegerField(default=0, help_text='Deposit amount charged in cents.'),
        ),
        migrations.AddField(
            model_name='payment',
            name='refund_status',
            field=models.CharField(default='not_refunded', max_length=30),
        ),
        migrations.AddField(
            model_name='payment',
            name='refunded_amount',
            field=models.PositiveIntegerField(default=0, help_text='Amount refunded in cents.'),
        ),
        migrations.AddField(
            model_name='payment',
            name='retained_deposit_amount',
            field=models.PositiveIntegerField(default=0, help_text='Deposit retained after late cancellation in cents.'),
        ),
        migrations.AddField(
            model_name='payment',
            name='service_total_amount',
            field=models.PositiveIntegerField(default=0, help_text='Full service amount in cents.'),
        ),
    ]
